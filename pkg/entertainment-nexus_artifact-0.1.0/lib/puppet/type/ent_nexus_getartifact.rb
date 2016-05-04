require 'pathname'
require 'puppet/parameter/boolean'
require 'puppet/parameter/path'

Puppet::Type.newtype(:ent_nexus_getartifact)  do
  @doc = <<-EOS
  Download an artifact to a location from nexus
  EOS

  def initialize(hash)
    super
    @stat = :needs_stat
  end

  newparam(:nexus_url) do
    desc "The nexus url https://nexus.prod.co.entpub.net/nexus"
    newvalues(/https?:\/\//, /\//)
    defaultto "https://nexus.prod.co.entpub.net/nexus"
  end

  newparam(:repo) do
    desc "The nexus repo id"
    defaultto "entertainment"
  end

  newparam(:group) do
    desc "The artifact group"
    isrequired
  end

  newparam(:artifact) do
    desc "The artifact name"
    isrequired
  end

  newparam(:packaging) do
    desc "The artifact packaging"
    defaultto "war"
  end

  newparam(:classifier) do
    desc "The artifact classifier"
    defaultto ""
  end

  newparam(:location, :parent => Puppet::Parameter::Path) do
    desc "The artifact file system location"
    isnamevar
  end

  newproperty(:owner) do
    desc "The downloaded artifact owner, argument can be a user name or a user ID"
    def insync?(current)
      # We don't want to validate/munge users until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.

      @should.map! do |val|
        provider.name2uid(val) or raise "Could not find user #{val}"
      end
      is_insync =false
      if @should.include?(current)
        is_insync = true
      end

      unless Puppet.features.root?
        warnonce "Cannot manage ownership unless running as root"
        is_insync=true
      end
      return is_insync
    end
    def retrieve
      provider.owner
    end

    def sync
      current = @resource.stat ? @resource.stat.uid: 0
      set_value=@should[0]

      if current!=set_value
        provider.owner = set_value
      end
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.uid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.uid2name(newvalue) || newvalue
    end

  end

  newproperty(:filegroup) do
    desc "The downloaded artifact owner group"
    validate do |group|
      raise(Puppet::Error, "Invalid group name '#{group.inspect}'") unless group and group != ""
    end
    def insync?(current)
      # We don't want to validate/munge groups until we actually start to
      # evaluate this property, because they might be added during the catalog
      # apply.
      @should.map! do |val|
        provider.name2gid(val) or raise "Could not find group #{val}"
      end
      result=@should.include?(current)
      return result
    end

    def retrieve
      provider.filegroup
    end

    def sync
      current = @resource.stat ? @resource.stat.gid: 0
      set_value= @should[0]

      if current!=set_value
        debug "prepare to set fielgroup to #{set_value}"
        provider.filegroup = set_value
      end
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.gid2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue)
      provider.gid2name(newvalue) || newvalue
    end
  end


  newparam(:tmp_dir, :parent => Puppet::Parameter::Path) do
    desc "The temp directory for downloading artifact"
    defaultto '/var/tmp'
  end

  newparam(:overwrite_mismatch, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether overwirte on disk artifact that has a mismatch sha1 sum"
    defaultto true
  end

  newproperty(:mode) do
    require 'puppet/util/symbolic_file_mode'
    include Puppet::Util::SymbolicFileMode
    desc "The file mode"

    munge do |value|
      return nil if value.nil?
      normalize_symbolic_mode(value)
    end

    def retrieve
      provider.mode
    end

    def insync?(current_value)
      return super(current_value)
    end

    def sync
      current = @resource.stat ? @resource.stat.mode: 0644
      #method in super class
      set(desired_mode_from_current(@should[0], current).to_s(8))
    end

    def desired_mode_from_current(desired, current)
      current = current.to_i(8) if current.is_a? String
      symbolic_mode_to_int(desired, current, false)
    end
    #override method in super class
    def property_matches?(current, desired)
      return false unless current
      current_bits = normalize_symbolic_mode(current)
      desired_bits = desired_mode_from_current(desired, current).to_s(8)
      current_bits == desired_bits
    end

  end

  newproperty(:version) do
    desc "The artifact version"
    isrequired

    def insync?(is)
      value =@should[0]
      return  true if provider.current_sha1_sum == provider.get_repo_sha1_sum(value)
      false
    end

    def retrieve
      provider.version
    end

    def sync
      value = @should[0]
      unless value
        value = 'LATEST'
      end
      provider.version=value
    end
  end

  newproperty(:ensure, :parent => Puppet::Property::Ensure) do
    defaultto :present

    newvalue(:present ) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end

    def retrieve
      return :present if provider.exists?
    end
  end

  {:user => :owner, :group => :filegroup}.each do |type, property|
    autorequire(type) do
      self[property]
    end
  end

  autorequire(:file) do
    req = []
    path = Pathname.new(self[:location])
    if !path.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path.parent.enum_for(:ascend)
      if found = parents.find { |p| catalog.resource(:file, p.to_s) }
        req << found.to_s
      end
    end

    path2 = Pathname.new(self[:tmp_dir])
    if !path2.root?
      # Start at our parent, to avoid autorequiring ourself
      parents = path2.parent.enum_for(:ascend)
      if found = parents.find { |p| catalog.resource(:file, p.to_s) }
        req << found.to_s
      end
    end
    req
  end

  def stat
    return @stat  unless @stat == :needs_stat
    method = :stat
    @stat = begin
      Puppet::FileSystem.send(method, self[:location])
    rescue Errno::ENOENT => error
      nil
    rescue Errno::ENOTDIR => error
      nil
    rescue Errno::EACCES => error
      warning "Could not stat; permission denied"
      nil
    end
  end

end
