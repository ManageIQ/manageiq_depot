#
# Description: Method: ImportVolume
#

require 'net/ssh'

begin
  @method = 'ImportVolume'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  @debug = true

  $evm.log("info", "#######################################") if @debug
  $evm.log("info", "") if @debug
  $evm.log("info", "==========================================") if @debug
  $evm.log("info", "Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k,v| $evm.log("info", "\t#{k}: #{v}") } if @debug

  def find_availabilityzone(vlan)
    vlan_db_path = "/JCDecaux/Integration/Infoblox/VLAN_DB"
    $evm.log("info", "[#{@method}] - Looking for availabilityzone associated to #{vlan} in #{vlan_db_path}") if @debug
    availabilityzone = nil
    $evm.instance_find("#{vlan_db_path}/*").each do |k, v|
      if k == vlan
        availabilityzone = v['availabilityzone']
        break
      end
    end
    return availabilityzone
  end

  def instance_update(name,hash)
    path = "/JCDecaux/Infrastructure/VM/Migrate/MigrateDB/#{name}"
    result = $evm.instance_update(path, hash)
    if result
      $evm.log('info',"Instance: <#{path}> updated. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not updated. Result:<#{result.inspect}>") if @debug
    end
    return result
  end

  $evm.log("info", "==========================================")
  $evm.log("info", "Running #{$evm.current_instance}")
  $evm.log("info", "==========================================")

  vm = $evm.root["vm"]

  vlan = $evm.root['dialog_option_0_acfsubnet']
  availabilityzone = find_availabilityzone(vlan)

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)

  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']

  disk = 2

  while disk < vm.num_hard_disks + 1 do
    Net::SSH.start(migrate_host, migrate_user) do |ssh|
      output = ssh.exec!("source .bash_profile; ec2-import-volume -O #{aws.authentication_userid} -W #{aws.authentication_password} --region #{aws.provider_region} /opt/AWS/#{vm.name}/#{vm.name}-disk#{disk}.vmdk -f VMDK -z #{availabilityzone} -b aws-import-manifest -o #{aws.authentication_userid} -w #{aws.authentication_password}")

      $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug

      matchdata = output.match(/TaskId\s+(?<TaskId>\S+)\s+/m)

      hash                  = {}
      hash['name']          = vm.name
      hash["taskid#{disk}"] = matchdata['TaskId']

      instance_update(hash['name'],hash)
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
