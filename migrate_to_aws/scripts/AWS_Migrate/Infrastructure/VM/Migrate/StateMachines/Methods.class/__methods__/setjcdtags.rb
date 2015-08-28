#
# Description: Method: SetJCDTags
#

require 'net/ssh'

begin
  @method = 'SetJCDTags'
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

  awsname = $evm.root['dialog_option_0_provider']
  aws = $evm.vmdb(:ems_amazon).find_by_name(awsname)
  aws.refresh

  migrateinfos = instance_get(vm.name)
  tmpinfos = migrateinfos[vm.name]
  instanceid = tmpinfos['instanceid'].split(",")
  user = $evm.root["user"]
  ugroup = user.miq_group
  if ugroup['filters'].present?
    filters = ugroup['filters']
    mfilters = filters['managed']
  end

  instanceid.each do |id|
    instance = $evm.vmdb('vm').find_by_ems_ref(id)
    while instance.nil?
      $evm.log("info","[#{@method}] - Waiting for instance object to be discovered by CloudForms") if @debug
      sleep(5)
      instance = $evm.vmdb('vm').find_by_ems_ref(id)
    end
    $evm.log("info","[#{@method}] - VM match found !! : #{instance}") if @debug
    instance.owner = user
    instance.group = ugroup
    if ugroup['filters'].present?
      mfilters.each do |f|
        ftmp = f.map{|e| e.sub('/managed/','').gsub(/"/,'')}
        tag = ftmp[0].split('/')
        tagcat = tag[0]
        tagval = tag[1]
        $evm.log("info","[#{@method}] - Filter: <#{tag}> - Tag Category: <#{tagcat}> - Tag Value: <#{tagval}>") if @debug
        instance.tag_assign("#{tagcat}/#{tagval}")
      end
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
