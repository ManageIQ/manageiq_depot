#
# Description: Method: ImportInstance
#

require 'net/ssh'

begin
  @method = 'ImportInstance'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  @debug = true
  
  $evm.log("info", "#######################################") if @debug
  $evm.log("info", "") if @debug
  $evm.log("info", "==========================================") if @debug
  $evm.log("info", "Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k,v| $evm.log("info", "\t#{k}: #{v}") } if @debug

  def find_subnetid(vlan)
    vlan_db_path = "/JCDecaux/Integration/Infoblox/VLAN_DB"
    $evm.log("info", "[#{@method}] - Looking for subnetid associated to #{vlan} in #{vlan_db_path}") if @debug
    subnetid = nil
    $evm.instance_find("#{vlan_db_path}/*").each do |k, v|
      if k == vlan
        subnetid = v['subnetid']
        break
      end
    end
    return subnetid
  end

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

  def instance_create(name,hash)
    path = "/JCDecaux/Infrastructure/VM/Migrate/MigrateDB/#{name}"
    result = $evm.instance_create(path, hash)
    if result
      $evm.log('info',"Instance: <#{path}> created. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not created. Result:<#{result.inspect}>") if @debug
    end
    return result
  end

  def instance_delete(name)
    path = "/JCDecaux/Infrastructure/VM/Migrate/MigrateDB/#{name}"
    result = $evm.instance_delete(path)
    if result
      $evm.log('info',"Instance: <#{path}> deleted. Result:<#{result.inspect}>") if @debug
    else
      $evm.log('info',"Instance: <#{path}> not deleted. Result:<#{result.inspect}>") if @debug
    end
    return result
  end

  $evm.log("info", "==========================================")
  $evm.log("info", "Running #{$evm.current_instance}")
  $evm.log("info", "==========================================")

  vm = $evm.root["vm"]
  vlan = $evm.root['dialog_option_0_acfsubnet']
  subnetid = find_subnetid(vlan)
  availabilityzone = find_availabilityzone(vlan)
  instancetype = $evm.root['dialog_option_0_acfinstancetype']

  unless vm.operating_system['product_name'].downcase.include?("windows")
    product_type = "Linux"
  else
    product_type = "Windows"
  end

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)

  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']

  Net::SSH.start(migrate_host, migrate_user) do |ssh|
    output = ssh.exec!("source .bash_profile; ec2-import-instance -O #{aws.authentication_userid} -W #{aws.authentication_password} --region #{aws.provider_region} -t #{instancetype} -f VMDK -a x86_64 -p #{product_type} -b aws-import-manifest -o #{aws.authentication_userid} -w #{aws.authentication_password} --subnet #{subnetid} -z #{availabilityzone} -d 'Migration #{vm.name}' /opt/AWS/#{vm.name}/#{vm.name}-disk1.vmdk")

    $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug

    matchdata = output.match(/TaskId\s+(?<TaskId>\S+)\s+.*InstanceID\s+(?<InstanceID>\S+)\s+/m)

    hash                 = {}
    hash['name']         = vm.name
    hash['instanceid']   = matchdata['InstanceID']
    hash['taskid1']      = matchdata['TaskId']

    instance_delete(hash['name'])
    instance_create(hash['name'],hash)
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
