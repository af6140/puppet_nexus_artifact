

Puppet::Type.type(:ent_nexus_getartifact).provide :nexus_fetch do
  require 'open-uri'
  require 'rexml/document'
  require 'etc'
  include Puppet::Util::POSIX
  include Puppet::Util::Warnings
  require 'puppet/util/symbolic_file_mode'
  include Puppet::Util::SymbolicFileMode
  confine :feature => :posix  
  commands :wget => 'wget'

  def initialize(avalue={})
    super(avalue)
    @property_flush = {}
  end

  def exists?
    return File.file?(@resource[:location])
  end

  def create
    debug "method_create: version=#{@resource[:version]}"
    current_version =self.version
    debug "method_create: current_version=#{current_version}"
    if  @resource[:version]
      artifact_version = @resource[:version]
    else
      artifact_version = "LATEST"
    end
    #nil, outdated snapshot
    if current_version.nil? || current_version!=artifact_version
      download_artifact(artifact_version)
    end
  end

  def destroy
    begin
      #not implemented yet
      rm('-f', @resource[:location])
    rescue Puppet::ExecutionFailure =>e
    end
  end

  def version
    debug "get version"
    if self.exists?
      ondisk_checksum= self.current_sha1_sum
      debug "File exists, fetch version from repo with sha1:#{ondisk_checksum}"
      #this only work with release version, for snapshots, only the latest
      # timestamped snapshot version is searchable wiith nexus
      version=get_version_sha1_in_repo(ondisk_checksum)
    else
      version=nil
    end
    #so for snapshot, if it's not the latest timestamed build version, it will always return nil
    debug "current version = #{version}"
    return version
  end

  def version=(value)
    debug("setting version to #{value}, resource version: #{@resource[:version]}")
    ver_repo_sha1=get_repo_sha1_sum(value)
    current_sha1 = self.current_sha1_sum
    debug "repo sha1=#{ver_repo_sha1} current_sha1=#{current_sha1}"
    if current_sha1.nil?
      self.create
    else
      if ver_repo_sha1 != current_sha1
        self.create
      end
    end
  end

  def mode
    debug("stat = #{@resource.stat.to_s}")
    if stat = @resource.stat
      return (stat.mode & 007777).to_s(8).rjust(4, '0')
    else
      return :absent
    end
  end

  def mode=(value)
    @property_flush[:mode] = value.to_i(8)
  end


  def filegroup
    debug "@resource.stat #{@resource.stat.to_s}"
    return :absent unless stat = @resource.stat

    currentvalue = stat.gid

    # On OS X, files that are owned by -2 get returned as really
    # large GIDs instead of negative ones.  This isn't a Ruby bug,
    # it's an OS X bug, since it shows up in perl, too.
    if currentvalue > Puppet[:maximum_uid].to_i
      self.warning "Apparently using negative GID (#{currentvalue}) on a platform that does not consistently handle them"
      currentvalue = :silly
    end

    currentvalue
  end

  def filegroup=(avalue)
    @property_flush[:filegroup] = avalue
  end

  def owner
    unless stat = @resource.stat
      return :absent
    end

    currentvalue = stat.uid

    # On OS X, files that are owned by -2 get returned as really
    # large UIDs instead of negative ones.  This isn't a Ruby bug,
    # it's an OS X bug, since it shows up in perl, too.
    if currentvalue > Puppet[:maximum_uid].to_i
      self.warning "Apparently using negative UID (#{currentvalue}) on a platform that does not consistently handle them"
      currentvalue = :silly
    end

    currentvalue
  end

  def owner=(avalue)
    @property_flush[:owner] = avalue
  end

  def get_version_sha1_in_repo(checksum)
    searchURI="#{@resource[:nexus_url]}/service/local/lucene/search?repositoryId=#{@resource[:repo]}&sha1=#{checksum}"
    debug "searchURI: #{searchURI}"
    xml_data = open(searchURI, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, :read_timeout=>30}).read
    debug "search version with sha1 result: #{xml_data}"
    doc = REXML::Document.new(xml_data) #Parse the xml for the resolved artifact
    #for snapshots, the seach only work with latest one, since there is only one version
    begin
      version_text= REXML::XPath.first(doc, "/searchNGResponse/data/artifact/version").text
    rescue
      veversion_text=nil
    end
    
    debug "version_text :#{version_text}"
    return version_text
  end

  def get_repo_sha1_sum(aversion)
    debug "get_repo_sha1_sum: version=#{aversion}"
    resolved = "#{@resource[:nexus_url]}/service/local/artifact/maven/resolve?r=#{@resource[:repo]}&v=#{aversion}&g=#{@resource[:group]}&a=#{@resource[:artifact]}&p=#{@resource[:packaging]}&c=#{@resource[:classifier]}"
    xml_data = open(resolved, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, :read_timeout => 20 }).read
    debug "resolved artifact: #{xml_data.to_s}"
    doc = REXML::Document.new(xml_data) #Parse the xml for the resolved artifact
    return REXML::XPath.first(doc, "/artifact-resolution/data/sha1").text
  end

  def current_sha1_sum
    check_sum=nil
    debug "Calculate current checksum"
    if File.file?(@resource[:location])
      check_sum=Digest::SHA1.file(@resource[:location]).hexdigest
    end
    debug "current checksum : #{check_sum}"
    return check_sum
  end

  # from puppet file posix provider
  def uid2name(id)
    return id.to_s if id.is_a?(Symbol) or id.is_a?(String)
    return nil if id > Puppet[:maximum_uid].to_i

    begin
      user = Etc.getpwuid(id)
    rescue TypeError, ArgumentError
      return nil
    end

    if user.uid == ""
      return nil
    else
      return user.name
    end
  end

  # Determine if the user is valid, and if so, return the UID
  def name2uid(value)
    Integer(value) rescue uid(value) || false
  end

  def gid2name(id)
    return id.to_s if id.is_a?(Symbol) or id.is_a?(String)
    return nil if id > Puppet[:maximum_uid].to_i

    begin
      group = Etc.getgrgid(id)
    rescue TypeError, ArgumentError
      return nil
    end

    if group.gid == ""
      return nil
    else
      return group.name
    end
  end

  def name2gid(value)
    debug "Convert name 2 gid #{value}"
    Integer(value) rescue gid(value) || false
  end

  #override parent class
  def flush
    if @property_flush
      if @property_flush[:mode]
        begin
          File.chmod(@property_flush[:mode], @resource[:location])
        rescue => detail
          raise Puppet::Error, "Failed to set mode to '#{@property_flush[:mode]}': #{detail}", detail.backtrace
        end
      end
      if @property_flush[:owner]
        begin
          File.chown(@property_flush[:owner],nil, @resource[:location])
        rescue => detail
          raise Puppet::Error, "Failed to set owner to '#{@property_flush[:owner]}': #{detail}", detail.backtrace
        end
      end
      if @property_flush[:filegroup]
        begin
          File.chown(nil, @property_flush[:filegroup], @resource[:location])
        rescue => detail
          raise Puppet::Error, "Failed to set group to '#{@property_flush[:filegroup]}': #{detail}", detail.backtrace
        end
      end

    end
  end

  private

  def download_artifact(aversion)
    debug "Download artifact version=#{aversion} nexus_url=#{@resource[:nexus_url]} group=#{@resource[:group]} location=#{@resource[:location]} owner=#{@resource[:owner]} filegroup=#{@resource[:filegroup]}"
    repo_sha1 = get_repo_sha1_sum(aversion)
    debug "SHA1 is repo = #{repo_sha1}"

    webArtifact = "#{@resource[:nexus_url]}/service/local/artifact/maven/redirect?r=#{@resource[:repo]}&v=#{aversion}&g=#{@resource[:group]}&a=#{@resource[:artifact]}&p=#{@resource[:packaging]}&c=#{@resource[:classifier]}"

    debug "webArtifact: #{webArtifact}"

    tmp = "/var/tmp/nexus_#{repo_sha1}"
    begin

      wget('--no-check-certificate', webArtifact , '-O', tmp)      
      FileUtils.cp tmp, @resource[:location]      
      File.chown(name2uid(@resource[:owner]), name2gid(@resource[:filegroup]), @resource[:location])

      if @resource[:mode]
        setting_mode=normalize_symbolic_mode(@resource[:mode] || "0644") # this returns a string of oct mode number
        real_mode =setting_mode =~ /\d+/ ? setting_mode.to_i(8):setting_mode        
        debug "changing mode to #{real_mode}(octal)"
        File.chmod real_mode , @resource[:location]
      end
      debug "Done chmod"
    rescue Puppet::ExecutionFailure => e
      debug "Failed to download artifact or change ownership and mode"
      #if failed remove the intermediate file
      #rm('-f', tmp)
      FileUtils.rm_f tmp
    end
    debug "Finished download artifact version=#{aversion}"
  end

end
