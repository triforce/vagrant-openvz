
module VagrantPlugins
  module Openvz
	class Driver
	  class CLI
		attr_accessor :name

		def initialize(sudo_wrapper, name = nil)
		  @sudo_wrapper = sudo_wrapper
		  @name         = name
		end

		def list
		  run(:vzlist,"-a").split(/\s+/).uniq
		end

		def fetch_ip(vzctlid)
		  run(:vzlist,"-a","-H","-o","ip","#{vzctlid}")
		end

		def fetch_ip_netadapter(vzctlid,netadapter)
          run(:vzctl,"exec","#{vzctlid}","ip -4 addr show #{netadapter} | egrep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | grep -v 255")
		end
		
		def create(vzctlid,settings={})

		  # run :rsync, settings[:box_location],settings[:template_location] 

		  run :prlctl, 'create', vzctlid, '--config', settings[:template_name], '--vmtype', 'ct'

		  settings.delete(:box_location)
		  settings.delete(:template_location)
		  settings.delete(:template_name)

		  settings.each do |key,value|
			run :vzctl,'set',vzctlid,"--#{key}","#{value}","--save"  
		  end

		end

		def set_netadapter(vzctlid,netadapter) 
		  run :vzctl,'set',vzctlid,"--netdev_add","#{netadapter}","--save"
          run :vzctl,'exec',vzctlid,"ifconfig","#{netadapter}","up"
          run :vzctl,'exec',vzctlid,"dhclient","#{netadapter}"
		end

		def start(vzctlid,pubkey)
		  run :vzctl, 'start', "#{vzctlid}"
		  add_vagrant_user(vzctlid,pubkey)
		end

		def destroy(vzctlid)
		  run :vzctl, 'destroy', "#{vzctlid}"
		end

		def stop(vzctlid)
		  run :vzctl, 'stop',  "#{vzctlid}"
		end

		def status(vzctlid)
		  if @name && run(:vzctl, 'status', "#{vzctlid}") =~ /^[a-z]+\s.*\s([a-z]+)\s([a-z]+)\s([a-z]+)$/i
			status = "#{$1}_#{$2}_#{$3}".downcase.to_sym
			status
		  elsif @name
			:unknown
		  end
		end

		def share_folder(source,destination) 
          run :mount, "-o", "bind", "#{source}", "#{destination}"
		end


		private


		def add_vagrant_user(vzctlid,pubkey)
		  run :vzctl, "exec",  "#{vzctlid}", "if [[ ! \`grep vagrant /etc/passwd\` ]]; then adduser --disabled-password --gecos 'vagrant test' vagrant; fi"
		  run :vzctl, "exec",  "#{vzctlid}", "mkdir -p /home/vagrant/.ssh" 
		  run :vzctl, "exec",  "#{vzctlid}", "echo '#{pubkey}' > /home/vagrant/.ssh/authorized_keys"
		  run :vzctl, "exec",  "#{vzctlid}", "chown -R vagrant:vagrant /home/vagrant/.ssh"
		  run :vzctl, "exec",  "#{vzctlid}", "echo 'vagrant    ALL=NOPASSWD:   ALL' > /etc/sudoers.d/vagrant"
		  run :vzctl, "exec",  "#{vzctlid}", "sed -i -e 's/Defaults    requiretty/#Defaults requiretty/' /etc/sudoers"
		end

		def run(command, *args)
		  @sudo_wrapper.run("#{command}", *args)
		end
	  end
	end
  end
end
