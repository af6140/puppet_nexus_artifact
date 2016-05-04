require 'spec_helper_acceptance.rb'

describe "nexus_artifact custom type" do
  context "download artifact" do 
    it "should work" do
      pp = <<-EOS
        group {'tomcat':
          name => 'tomcat',
          ensure => present
        } -> 
        user {'tomcat':
          groups => ['tomcat'],
          home => '/var/lib/tomcat',
          managehome => true,
          ensure => present,
        } ->
        ent_nexus_getartifact{'/var/lib/tomcat/coupon_app-static.tar':
          group => 'webapps',
          artifact => 'coupon_app-static',
          version => '1.0.2',
          repo => 'entertainment',
          packaging => 'tar',
          owner => 'tomcat',
          filegroup => 'tomcat',
          mode => '0644',
          ensure => 'present',
        }
      EOS
      # Run it twice and test for idempotency
      apply_manifest(pp, {:debug => true, :catch_failures => true})
      apply_manifest(pp, {:debug => true, :catch_changes  => true})

    end

    describe file('/var/lib/tomcat/coupon_app-static.tar') do
      it { should exist }
      it { should be_owned_by 'tomcat'}
      it { should be_mode 644 }
    end
 end

 context "download artifact same version, mode change" do 
    it "should work" do
      pp = <<-EOS
        ent_nexus_getartifact{'/var/lib/tomcat/coupon_app-static.tar':
          group => 'webapps',
          artifact => 'coupon_app-static',
          version => '1.0.2',
          repo => 'entertainment',
          packaging => 'tar',
          owner => 'nobody',
          filegroup => 'nobody',
          mode => '0755',
          ensure => 'present',
        }
      EOS
      # Run it twice and test for idempotency
      apply_manifest(pp, {:debug => true, :catch_failures => true})
    end

    describe file('/var/lib/tomcat/coupon_app-static.tar') do
      it { should exist }
      it { should be_owned_by 'nobody'}
      it { should be_mode 755 }
    end
 end

 context "download artifact different version, owner change " do 
  it "should work" do
    pp = <<-EOS      
      ent_nexus_getartifact{'/var/lib/tomcat/coupon_app-static.tar':
        group => 'webapps',
        artifact => 'coupon_app-static',
        version => '1.0.3',
        repo => 'entertainment',
        packaging => 'tar',
        owner => 'root',
        filegroup => 'root',
        mode => '0755',
        ensure => 'present',
      }
    EOS
    # Run it twice and test for idempotency
    apply_manifest(pp, {:debug => true, :catch_failures => true})
  end

  describe file('/var/lib/tomcat/coupon_app-static.tar') do
     it { should exist }
     it { should be_owned_by 'root'}
     it { should be_mode 755 }
     its(:md5sum) { should eq 'c75f754f66813719e56e0d84ef8305db' }
  end
 end

 context "download artifact latest version" do 
  it "should work" do
    pp = <<-EOS
      ent_nexus_getartifact{'/var/lib/tomcat/cosmos.war':
        group => 'com.entertainment.redbox',
        artifact => 'cosmos-web',
        repo => 'entertainment_snapshots',
        packaging => 'war',
        owner => 'tomcat',
        filegroup => 'tomcat',
        mode => '0644',
        ensure => 'present',
      }
    EOS
    # Run it twice and test for idempotency
    apply_manifest(pp, {:debug => true, :catch_failures => true})
  end

  describe file('/var/lib/tomcat/cosmos.war') do
     it { should exist }
     it { should be_owned_by 'tomcat'}
     it { should be_mode 644 } 
  end
 end
end

