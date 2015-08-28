#
# Description: Method: ExportVM
#

require 'net/ssh'

begin
  @method = 'ExportVM'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  @debug = true

  $evm.log("info", "#######################################") if @debug
  $evm.log("info", "") if @debug
  $evm.log("info", "==========================================") if @debug
  $evm.log("info", "Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k,v| $evm.log("info", "\t#{k}: #{v}") } if @debug

  $evm.log("info", "==========================================")
  $evm.log("info", "Running #{$evm.current_instance}")
  $evm.log("info", "==========================================")

  vm = $evm.root["vm"]

  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']
  
  Net::SSH.start(migrate_host, migrate_user) do |ssh|
    output = ssh.exec!("rm -fr /opt/AWS/#{vm.name}; /usr/bin/ovftool vi://sysop:rnUgaP-r+uJ.@vcenter5/#{vm.datacenter.name}/vm/#{vm.name} /opt/AWS/")
        
    $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug
    unless output =~ /completed successfully/i
      raise "ExportVM failed"
    end
  end  

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

#
# Set Ruby rescue behavior
#
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
