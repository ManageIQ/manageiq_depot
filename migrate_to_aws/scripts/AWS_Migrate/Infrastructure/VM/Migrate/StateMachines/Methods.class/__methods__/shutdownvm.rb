#
# Description: Method: ShutdownVM
#
begin
  @method = 'ShutdownVM'
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
  
  unless vm.nil? || vm.attributes['power_state'] == 'off'
    $evm.log('info', "Powering Off VM <#{vm.name}>")
    vm.stop
  end

  vm.refresh
    
  power_state = vm.attributes['power_state']

  if power_state == "off" || power_state == "suspended"
    $evm.root['ae_result'] = 'ok'
  else
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '15.seconds'
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
