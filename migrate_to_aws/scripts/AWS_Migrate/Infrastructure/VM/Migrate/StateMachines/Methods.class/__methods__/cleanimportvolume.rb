#
# Description: Method: CleanImportVolume
#

require 'net/ssh'

begin
  @method = 'CleanImportVolume'
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

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)

  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']

  disk = 2

  while disk < vm.num_hard_disks + 1 do
    taskid = tmpinfos["taskid#{disk}"].split(",").first

    Net::SSH.start(migrate_host, migrate_user) do |ssh|
      output = ssh.exec!("source .bash_profile; ec2-delete-disk-image -O #{aws.authentication_userid} -W #{aws.authentication_password} --region #{aws.provider_region} -t #{taskid} -o #{aws.authentication_userid} -w #{aws.authentication_password}")

      $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug
    end
    disk+=1
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
