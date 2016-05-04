require 'spec_helper'
require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
require 'beaker/puppet_install_helper'
require 'json'

hosts.each do |host|
 if host['roles'].include?('centos') and host['roles'].include?('agent')  
  run_puppet_install_helper unless ENV['BEAKER_provision'] == 'no'
  case fact_on(host, "osfamily")
  when 'RedHat'
      case JSON.parse(fact_on(host,'os').gsub('=>',':'))['release']['major']
      when '7'        
        install_package(host, 'deltarpm')
        on host, 'yum -y update'
        %w(bzip2 tar wget initscripts git).each do |pkg_to_install|
          install_package(host, pkg_to_install)
        end
      when '6'
        %w(bzip2 targ wget git).each do |pkg_to_install|
          install_package(host, pkg_to_install)
        end
      else 
        puts fact_on(host,'os')
      end
  end
 end
end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(:source => proj_root, :module_name => 'nexus_artifact')
    master = ''
    begin
      master = only_host_with_role(hosts, 'master')
      master_fqdn = "#{master}"
    rescue => error
      puts "No puppet master defined."
    end

    hosts.each do |host|

      #configure agent to use future parser and strict variables
      if host['roles'].include?('agent')
        agent = host
        agent_name = agent.to_s.downcase
        agent_fqdn ="#{agent_name}"

        config = {
            'main' => {
                'server' => master_fqdn,
                'certname' => agent_fqdn,
                'parser' => 'future',
                'strict_variables' => 'true',
                'plugin_sync' => 'true',
            }
        }
        
        configure_puppet_on(agent, config)

        #todo, need to setup hiera conf/data here
        hierarchy = 'common'
        write_hiera_config_on(host, hierarchy)
        copy_hiera_data_to(host, 'spec/fixtures/hiera/hieradata')
        on host, puppet('module', 'install', 'puppetlabs/stdlib'  ), { :acceptable_exit_codes => [0,1] }        

        
      end
    end
  end
end
