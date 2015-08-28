#
# Description: Method: CheckImportInstance
#

require 'net/ssh'

begin
  @method = 'CheckImportInstance'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  @debug = true

  $evm.log("info", "#######################################") if @debug
  $evm.log("info", "") if @debug
  $evm.log("info", "==========================================") if @debug
  $evm.log("info", "Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k,v| $evm.log("info", "\t#{k}: #{v}") } if @debug

  def instance_get(name)
    path = "/JCDecaux/Infrastructure/VM/Migrate/MigrateDB/#{name}"
    result = $evm.instance_find(path)
    if result
      $evm.log('info',"Instance: <#{path}> fetched. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not found. Result:<#{result.inspect}>") if @debug
      exit MIQ_ABORT
    end
    return result
  end

  $evm.log("info", "==========================================")
  $evm.log("info", "Running #{$evm.current_instance}")
  $evm.log("info", "==========================================")

  vm = $evm.root["vm"]

  migrateinfos = instance_get(vm.name)
  tmpinfos = migrateinfos[vm.name]
  taskid = tmpinfos['taskid1'].split(",").first

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)
  
  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']

  Net::SSH.start(migrate_host, migrate_user) do |ssh|
    output = ssh.exec!("source .bash_profile; ec2-describe-conversion-tasks -O #{aws.authentication_userid} -W #{aws.authentication_password} --region #{aws.provider_region} #{taskid}")

    $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug

    matchdata = output.match(/Status\s+(?<TaskStatus>\S+)\s+/)

    case matchdata['TaskStatus']
    when 'active'
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = '1.minute'
    when 'cancelled'
      $evm.root['ae_result'] = 'error'
      raise "cancelled"
    when 'cancelling'
      $evm.root['ae_result'] = 'error'
      raise "cancelling"
    when 'completed'
      $evm.root['ae_result'] = 'ok'
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
