#
# Description: Method: SetAWSTags
#

require 'net/ssh'

begin
  @method = 'SetAWSTags'
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
  instanceid = tmpinfos['instanceid'].split(",").first
  environment = $evm.root['dialog_option_0_acftagenvironnement'].first.name
  workhours = $evm.root['dialog_option_0_acfTagWorkhours'].sub(/1|t/,"true").sub(/0|f|null/,"false")
  snapshot = $evm.root['dialog_option_0_acfTagSnapshot'].sub(/1|t/,"true").sub(/0|f|null/,"false")
  user = $evm.root["user"]
  owner = user["name"]

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)
  
  migrate_host = $evm.object['migrate_host']
  migrate_user = $evm.object['migrate_user']

  Net::SSH.start(migrate_host, migrate_user) do |ssh|
    output = ssh.exec!("source .bash_profile; ec2-create-tags -O #{aws.authentication_userid} -W #{aws.authentication_password} --region #{aws.provider_region} -t Name=\"#{vm.name}\" -t Description=\"Migration\" -t Environnement=\"#{environment}\" -t Owner=\"#{owner}\" -t Snapshot=\"#{snapshot}\" -t Workhours=\"#{workhours}\" #{instanceid}")

    $evm.log('info', "#{@method} - Inspect output: #{output.inspect}") if @debug
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
