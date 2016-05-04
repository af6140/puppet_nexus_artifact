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
        ent_nexus_getartifact{'/var/lib/tomcat/cpf-api-client.jar':
          nexus_url => 'https://oss.sonatype.org',
          group => 'ca.bc.gov.open.cpf',
          artifact => 'cpf-api-client',
          version => '5.0.0-SNAPSHOT',
          repo => 'snapshots',
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

    describe file('/var/lib/tomcat/cpf-api-client.tar') do
      it { should exist }
      it { should be_owned_by 'tomcat'}
      it { should be_mode 644 }
    end
 end

 context "download artifact same version, mode change" do 
    it "should work" do
      pp = <<-EOS
        ent_nexus_getartifact{'/var/lib/tomcat/cpf-api-client.tar':
          nexus_url => 'https://oss.sonatype.org',
          group => 'ca.bc.gov.open.cpf',
          artifact => 'cpf-api-client',
          version => '5.0.0-SNAPSHOT',
          repo => 'snapshots',
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

    describe file('/var/lib/tomcat/cpf-api-client.tar') do
      it { should exist }
      it { should be_owned_by 'nobody'}
      it { should be_mode 755 }
    end
 end

 context "download artifact different version, owner change " do 
  it "should work" do
    pp = <<-EOS      
      ent_nexus_getartifact{'/var/lib/tomcat/cpf-api-client.tar':
        nexus_url => 'https://oss.sonatype.org',
        group => 'ca.bc.gov.open.cpf',
        artifact => 'cpf-api-client',
        version => '5.0.0-SNAPSHOT',
        repo => 'snapshots',
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

  describe file('/var/lib/tomcat/cpf-api-client.jar') do
     it { should exist }
     it { should be_owned_by 'root'}
     it { should be_mode 755 }     
  end
 end

 context "download artifact latest version" do 
  it "should work" do
    pp = <<-EOS
      ent_nexus_getartifact{'/var/lib/tomcat/cpf-api-client.jar':
        nexus_url => 'https://oss.sonatype.org',
        group => 'ca.bc.gov.open.cpf',
        artifact => 'cpf-api-client',
        repo => 'snapshots',
        packaging => 'jar',
        owner => 'tomcat',
        filegroup => 'tomcat',
        mode => '0644',
        ensure => 'present',
      }
    EOS
    # Run it twice and test for idempotency
    apply_manifest(pp, {:debug => true, :catch_failures => true})
  end

  describe file('/var/lib/tomcat/cpf-api-client.jar') do
     it { should exist }
     it { should be_owned_by 'tomcat'}
     it { should be_mode 644 } 
  end
 end
end

