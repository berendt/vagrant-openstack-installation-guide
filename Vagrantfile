require 'yaml'

unless defined? ENVIRONMENT
  environment_file = File.join(File.dirname(__FILE__), 'environment.yaml')
  ENVIRONMENT = YAML.load(File.open(environment_file, File::RDONLY).read)
end

Vagrant.configure(2) do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true
  ENVIRONMENT.each do |name, details|
    config.vm.define name do |node|
      node.vm.box = details['box']
      node.vm.hostname = name
      node.vm.network :private_network, ip: details['address']
      node.vm.provider 'virtualbox' do |vb|
        vb.customize ['modifyvm', :id, '--memory', details['memory']]
        vb.customize ['modifyvm', :id, '--cpus', details['cpus']]
      end
      if details.has_key?('storage')
        node.vm.provider 'virtualbox' do |vb|
          vb.customize ['createhd', '--filename', "#{name}.vdi",
                        '--size', details['storage']]
          vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller',
                        '--port', 1, '--device', 0, '--type', 'hdd', '--medium',
                        "#{name}.vdi"]
        end
      end
    end
  end
end
