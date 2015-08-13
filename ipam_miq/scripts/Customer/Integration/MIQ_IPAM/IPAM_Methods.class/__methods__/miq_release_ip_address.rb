###################################
#
# EVM Automate Method: miq_release_ip_address
#
# Notes: EVM Automate method to release IP Address information from EVM Automate Model
#
###################################
# Method for logging
###################################
def log(level, message)
  @method = 'miq_release_ip_address'
  @debug = true
  $evm.log(level, " - - #{message}") if @debug
end


##############
# Converts a string to a boolean
# @param string [String] the string to convert
# @return [Boolean] the value cast from the string
##############
def boolean(string)
  return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
  return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

  # Return false if string does not match any of the above
  log(:info, "Invalid boolean string:<#{string}> detected. Returning false")
  return false
end


############################
# Method: instance_get
# Notes: Returns hash
############################
def instance_get(path)
  result = $evm.instance_get(path)
  $evm.log('info', "Instance:<#{path}> properties:<#{result.inspect}>") 
  return result
end


##############
# Finds instances based on a datastore path
# @param path [String] the path where to look for instances : MUST start with the domain name
# @return [Hash] the hash containing all the instances under the path
##############
def instance_find(path)
  result = $evm.instance_find(path)
  # Returns Hash
  #$evm.log('info',"Instance:<#{path}> properties:<#{result.inspect}>") 
  return result
end


############################
# Method: instance_update
# Notes: Returns string: true/false
############################
def instance_update(path, hash)
  result = $evm.instance_update(path, hash)
  if result
    $evm.log('info', "Instance:  <#{path}> updated. Result:<#{result.inspect}>") 
  else
    $evm.log('info', "Instance:  <#{path}> not updated. Result:<#{result.inspect}>") 
  end
  return result
end


############################
# Method: instance_exists
# Notes: Returns string: true/false
############################
def instance_exists(path)
  result = $evm.instance_exists?(path)
  if result
    $evm.log('info', "Instance: <#{path}> exists. Result:<#{result.inspect}>") 
  else
    $evm.log('info', "Instance: <#{path}> does not exist. Result:<#{result.inspect}>") 
  end
  return result
end


############################
# Method: set_displayname
# Notes: This method set an instance DisplayName
# Returns: Returns: true/false
############################
def set_displayname(path, display_name)
  result = $evm.instance_set_display_name(path, display_name)
  return result
end


############################
# Method: validate_hostname
# Notes: This method uses a regular expression to find an instance that contains the hostname
# Returns: Returns string: true/false
############################
def validate_hostname(hostname)
  hostname_regex = /(hostname)$/
  if hostname_regex =~ hostname
    log(:info, "#{@method} Hostname:<#{hostname}> found") 
    return true
  else
    $evm.log("error", "#{@method} Hostname:<#{hostname}> not found") 
    return false
  end
end


begin

  #######
  #  We need to build in a rescue release of IP if a provision request failed to complete but DID reserve an IP
  #######
  # Get Provisioning Object: This will be nil if manually provisioned outside of CloudForms
  prov = $evm.root["miq_provision"]
  log(:info, "#{@method}  Inspect prov object: <#{prov.inspect}>") 

  # Get current VM object, this will be nil if a provision request failed during processing
  vm = $evm.root['vm']
  raise "#{@method} VM or Provision Object not found and cannot release IP" if vm.nil? && prov.nil?

  # # # #
  # Check to see if the VM has been tagged with 'miq_ipam_db_name'.
  # If so, release the IP from the ManageIQ IPAM system.
  # # # #
  ipam_db_name = nil
  if vm.to_s != ''
    vm_name = vm.name
    vm.tags.sort.each { |tag_element| tag_text = tag_element.split('/');
    if tag_text.first == "atg_ipam_path"
      ipam_db_name = tag_text.last.to_s
      log("info", " VM:<#{vm.name}> Category:<#{tag_text.first.inspect}> Tag:<#{tag_text.last.inspect}>")
    end
    }
  elsif prov.to_s != ''
    vm_name = prov.get_option(:vm_target_name)
    ipam_db_name = prov.get_tags[:atg_ipam_path]
    log(:info, "prov.get_tags[:atg_ipam_path] = #{ipam_db_name}")
  end

  ## If we can't get the IPAM Database name from the VM or Provision tags, just exit
  if ipam_db_name.nil? || !ipam_db_name
    log(:info, " IPAM was not used, moving on.")
    exit MIQ_OK
  end


  ## We have an IPAM Database name, so we can go on
  log(:info, " IPAM DB Name: #{ipam_db_name}")

  ## We get the IPAM Database path from the IPAM configuration and database name
  IPAM_preamble = $evm.object['path_to_ipams'] || '/Customer/Integration/MIQ_IPAM/'

  ## We get the IPAM Database path from the IPAM configuration and database name
  ipam_db_path = "#{IPAM_preamble}#{ipam_db_name}"
  log(:info, "Release IP from IPAM DB: ipam_db_path: #{ipam_db_path}")
  search_path = "#{ipam_db_path}/*"
  log(:info, " Release IP from IPAM DB: #{ipam_db_path}")

  ## Find an instance that matches the VM's IP Address
  instance_hash = instance_find(search_path)
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?

  ## Look for IP Address candidate that validates hostname
  ip_candidate = instance_hash.find { |k, v| v['hostname'] == vm_name }
  if ip_candidate.nil?
    log(:warn, " No instance matches the VM '#{vm_name}', so nothing to be done.")
    exit MIQ_OK
  end

  ## Assign first element in array to the instance name
  class_instance = ip_candidate.first

  ## Assign last element to new_hash, so that we can update its attributes
  new_hash = ip_candidate.last

  location = "#{ipam_db_path}/#{class_instance}"
  log(:info, " Found instance: <#{location}> with Values: <#{new_hash.inspect}>")

  ## Set the inuse attribute to false and the release date to now
  new_hash['inuse'] = 'false'
  new_hash['date_released'] = Time.now.strftime('%a, %b %d, %Y at %H:%M:%S %p')
  new_hash['date_acquired'] = nil

  ## Update instance and display name
  if instance_update(location, new_hash)
    set_displayname(location, nil)
  else
    raise "#{@method} Failed to update instance:<#{location}>"
  end

  #
  # Exit method
  #
  log(:info, "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  log(:error, "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
###################################
# End of EVM Automate Method: miq_release_ip_address
###################################
