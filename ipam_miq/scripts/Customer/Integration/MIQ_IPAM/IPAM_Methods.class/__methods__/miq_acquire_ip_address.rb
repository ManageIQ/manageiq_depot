###################################
#
# EVM Automate Method: miq_acquire_ip_address
#
# Notes: EVM Automate method to acquire IP Address information from EVM Automate Model
#
###################################

###################################
# Method for logging
###################################
def log(level, message)
  @method = 'miq_acquire_ip_address'
  @debug = true
  $evm.log(level, " - - #{message}") if @debug
end


##############
# This is a check to see if server is a dev server.  This may need to be updated if lab servers do not contain 'dev'
# in their hostnoame.
# @return [Boolean] if in the lab/dev environment
##############
def is_lab
  #find out if in dev environment
  return $evm.root['miq_server'].name.downcase.include? "dev" || false
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


##############
# Finds instances based on a datastore path
# @param path [String] the path where to look for instances : MUST start with the domain name
# @return [Hash] the hash containing all the instances under the path
##############
def instance_find(path)
  result = $evm.instance_find(path)
  log(:info, "Path:<#{path}> - Properties:<#{result.inspect}>")
  return result
end


##############
# Updates the data of a specific instance
# @param path [String] the path of the instance to update
# @param data [Hash] the data that will update the instance
# @return [Boolean] true if the update was successful, false otherwise
##############
def instance_update(path, data)
  log(:info, "Path:<#{path}> - Data:<#{data.inspect}> ")

  result = $evm.instance_update(path, data)
  if result
    log(:info, "Instance: <#{path}> updated. Result:<#{result.inspect}>")
  else
    $evm.log("error", "Instance: <#{path}> NOT updated. Result:<#{result.inspect}>")
  end
  return result
end


##############
# Validates the IP address against a regular expression
# @param ip [String] the IP address to validate
# @param optional_flag [Boolean] whether the validation is required
# @return [Boolean] true if the IP address validates, false otherwise
##############
def validate_ipaddr(ip, optional_flag)
  # If the IP is not mandatory, return true
  if ip.nil? || boolean(optional_flag)
    return true
  end

  ip_regex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
  if ip_regex =~ ip
    log(:info, "IP Address:<#{ip}> passed validation")
    return true
  else
    $evm.log("error", "IP Address:<#{ip}> failed validation")
    return false
  end
end


##############
# Validates the gateway IP address against a regular expression
# @param optional_flag [Boolean] whether the validation is required
# @return [Boolean] true if the IP address validates, false otherwise
##############
def validate_gateway(gateway_ip)
  ip_regex = /\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b/
  if ip_regex =~ gateway_ip
    log(:info, "Default Gateway:<#{gateway_ip}> passed validation")
    return true
  else
    $evm.log("error", "Default Gateway:<#{gateway_ip}> failed validation")
    return false
  end
end


##############
# Validates the subnet mask against a regular expression
# @param submask [String] the subnet mask to validate
# @param optional_flag [Boolean] whether the validation is required
# @return [Boolean] true if the subnet mask validates, false otherwise
##############
def validate_submask(submask, optional_flag)
  # If the subnet mask is not mandatory, return true
  if submask.nil? || boolean(optional_flag)
    return true
  end
  mask_regex = /^(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255).(0|128|192|224|240|248|252|254|255)$/
  if mask_regex =~ submask
    log(:info, "Subnet Mask:<#{submask}> passed validation")
    return true
  else
    $evm.log("error", "Subnet Mask:<#{submask}> failed validation")
    return false
  end
end


##############
# Sets an instance DisplayName
# @param path [String] the path of the instance we want to set the display name
# @param display_name [String] the display name we want to set
# @return [Boolean]: true if the display name has been set, false otherwise
##############
def set_displayname(path, display_name)
  result = $evm.instance_set_display_name(path, display_name)
  return result
end


##############
# Gets an IP address
# @param search_path [String] the path in which we look for IP addresses
# @param ipam_db_name [String] the name of the IPAM Database we are looking into
# @return [Hash] the hash corresponding to the entry in the IPAM Database
##############
def get_ip_address(search_path, ipam_db_name)
  # Retrieve all the instances in the search path and raise an exception if none is returned
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?

  # Remove hash elements where inuse = true|TRUE and raise an exception if the hash is empty
  instance_hash.delete_if { |k, v| v['inuse'] =~ /^true$/i }
  raise "No IP Addresses are free" if instance_hash.empty?

  # Look for an IP Address candidate that validates ipaddr, gateway and submask, and raise an exception if there is no match
  ip_candidate = instance_hash.find { |k, v| validate_ipaddr(v['ipaddr'], false) && validate_submask(v['submask'], false) && validate_gateway(v['gateway']) && validate_ipaddr(v['ipaddr2'], true) && validate_submask(v['submask2'], true) }
  raise "No available IP Addresses passed the validation step." if ip_candidate.nil?
  log(:info, "Found instance:<#{ip_candidate.inspect}>")

  # Trigger an email based on the number of available IPs, once we remove the candidate
  send_ip_count_email(instance_hash.length, ipam_db_name.upcase)

  return ip_candidate
end


##############
# Reserves an IP address
# @param ip_candidate [String] the IP address candidate to reserve
# @param location [String] the location of the IP address candidate
# @param reservation_token [String]
##############
def reserve_ip_address(ip_candidate, location, reservation_token)
  log(:info, " Attempt to reserve IP:<#{location}> with <#{ip_candidate.inspect}>")

  ip_candidate['inuse'] = 'true'
  ##  Now we'll use the request ID as a unique token to set on the IPAM row.  Later in the code, we'll check to ensure
  ##  our unique token still has the IPAM row reserved, if not, we'll get another IPAM row and set & check again.
  ip_candidate['reserve_token'] = reservation_token

  updated = instance_update(location, ip_candidate)
  log(:info, "#186 Reserved  #{location}: #{ip_candidate['hostname']}/#{ip_candidate['ipaddr']} with reservation token: #{ip_candidate['reserve_token']}")
  log(:info, "#187 Reserved IP address: <#{updated}> with Values:#{location} => #{ip_candidate.inspect}")
end


##############
# Validate reservation token
# @param location [String] the path of the IP address candidate
# @param reservation_token [String] the reservation_token to validate
# @return [Boolean] true if the reservation token validates, false otherwise
##############
def validate_reservation_token(location, reservation_token)
  ## For added insurance against a race condition, the following sleep provides a small random interval
  ## between requests for validating their reserve_token
  rest = (rand(20)+rand(20)).seconds
  $evm.log("info","#{@method} Sleeping for #{rest} seconds")
  sleep rest


  updated_hash = instance_find("#{location}")

  ipaddr, ip_row_info = updated_hash.first
  log(:info, "Need to confirm token - request ID: <#{reservation_token}>  with IP row info: #{updated_hash.inspect}")
  if reservation_token.to_s == ip_row_info['reserve_token'].to_s
    log(:info, "CONFIRMED MATCH of Reservation tokens - reserve_token:<#{ip_row_info['reserve_token']}>  Request ID: <#{reservation_token}>")
    return true
  else
    log(:info, "FAILED MATCH of Reservation tokens - reserve_token:<#{ip_row_info['reserve_token']}>  Request ID: <#{reservation_token}>")
    return false
  end
end


##############
# Sends a warning or error email depending on available IPs
# @param ip_count [Integer] the count of available IPs still available
# @param ipam_db_name [String] the name of the concerned IPAM database
##############
def send_ip_count_email(ip_count, ipam_db_name)
  low_ip_threshold = $evm.object['db_low_warning'] || 5  #default to five if not set on instance
  ip_count -= 1 # We assume we will be able to acquire the IP Address
  log(:info, "---CAI--- IPAM COUNT: #{ipam_db_name} - #{ip_count} ")

  case ip_count
    when 0
      subject = "#{@lab_text}ACTION: No IP addresses available for automation workflow"
      msg = "IPAM Database \"#{ipam_db_name}\" has no IP/Hostname values available."
      msg += "<br>Please, confirm the availablity of IPs and notify end user of the root cause of failure."
      $evm.log("error", "No IP addresses available for #{ipam_db_name}")
    when 1..low_ip_threshold
      subject = "#{@lab_text}ACTION:  Running low on IP addresses for #{ipam_db_name}"
      msg = "Only #{ip_count} IP addresse(s) available for \"#{ipam_db_name}\"."
      msg += "<br>Please, confirm the availablity of IPs."
      $evm.log("warn", "Only #{ip_count} IP addresse(s) available for #{ipam_db_name}")
    else
      # We have more than 5 IPs available, so we don't have to send an email
      return
  end

  # Build the email
  to = $evm.object['to_email_address']
  from = $evm.object['from_email_address']
  signature = $evm.object['signature']
  body = "Hello, "
  body += "<br><br> #{msg}"
  body += "<br><br> Thank you,"
  body += "<br>#{signature}"

  # Send the email
  log(:info, "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute('send_email', to, from, subject, body)
end


###########  Begin Processing  ###########
begin
  # Get Provisioning Object
  @prov = $evm.root["miq_provision"]
  @lab_text = is_lab() ? "* LAB * " : ""

  tags = @prov.get_tags
  log(:info, "Provision request tags: <#{tags.inspect}>")

  # This entire method (AcquireIPAddress) is only used for workflows requiring the IPAM values.
  # Therefore, the following tag is the driver to let this code know which IPAM DB to call.
  # This tag MUST be created and set in the CustomizeRequest state, otherwise we raise an exception.
  ipam_db_name = tags[:atg_ipam_path]
  log(:info, "Using miq_ipam_path <#{ipam_db_name}>")
  raise "<atg_ipam_path> tag is nil" if ipam_db_name.nil?

  IPAM_preamble = $evm.object['path_to_ipams'] || '/Customer/Integration/MIQ_IPAM/'

  # We get the IPAM Database path from the IPAM configuration and database name
  ipam_db_path = "#{IPAM_preamble}#{ipam_db_name}"
  log(:info, "ipam_db_path: #{ipam_db_path}")
  search_path = "#{ipam_db_path}/*"

  # We use the request ID as a unique identifier to reserve the IPAM entry
  reservation_token = @prov.id

  # We were running into a race situation for IP allocation from the IPAM.  Created the following loop to
  #   1. Get an available IP instance
  #   2. Reserve the instance using the RequestID as a unique identifier (reserve_token)
  #   3. Confirm reservation by retrieving the record and confirm the reserve_token values is same as request ID
  #   4. If it doesn't match, do the loop again

  i = 0
  begin
    log(:info, "Staring the IP Get/Reserve/Validate block")

    # Added a counter to break out of loop if stuck for 10 times
    max_retries = $evm.object['max_reservation_retries'] || 10
    i += 1
    if i >= max_retries
      raise "We already looped #{max_retries} times, we abort."
      #break
    end

    # Call IPAM DB and get back a IP entry instance
    ip_candidate_hash = get_ip_address(search_path, ipam_db_name)

    # Set the IPAM instance location so we can call the DB and get just this IPAM row
    ip_candidate_path = "#{ipam_db_path}/#{ip_candidate_hash.first}"
    ip_candidate = ip_candidate_hash.last
    log(:info, "IP Candidate <#{ip_candidate_path.inspect}> : <#{ip_candidate.inspect}>")

    # Try to reserve the IP address by flipping the "inuse" flag and setting the "reserve_token" (requestion ID)
    reserve_ip_address(ip_candidate, ip_candidate_path, reservation_token)

    # The following sleep is to provide a small interval between requests validating their reserve_token
#    rest = (rand(20)+rand(20)).seconds
#    log(:info, "Sleeping for #{rest} seconds")
#    sleep rest

    # Now we'll call directly to DB to get the IP row again and confirm that our request ID is still the reserve_token
    # value.  If not, it means that we have a race situation and another process is also trying to use this IP value.
    # If different, we will get another IP row and once again reserve & validate
    reserved = validate_reservation_token(ip_candidate_path, reservation_token)
    if reserved
      log(:info, "Validated Reservation: <#{reservation_token}> was successful: <#{reserved}>")
    else
      log(:info, "Two requests attempting to use same IP: <#{ip_candidate.inspect}> Token: <#{reservation_token}>")
    end
  end while !reserved


  # Override Customization Specification
  @prov.set_option(:sysprep_spec_override, [true, 1])
  if @prov.options.has_key?(:ws_values)
    @ws_values = @prov.options[:ws_values]
  else
    @ws_values = Hash.new
  end


  # Some BUs need to define the machine name but use the other values from the IPAM. To release the IP correctly,
  # we need to update the IPAM instance with the new name
  dynamic_hostname = tags[:miq_dynamic_hostname] || 'false'
  if boolean(dynamic_hostname)
    log(:info, "dynamic_hostname <#{dynamic_hostname}> ")
      user_defined_name = @prov.get_option(:vm_name) || @ws_values[:vm_name]
      log(:info, "user_defined_name <#{user_defined_name.inspect}> ")
      @prov.set_option(:linux_host_name, user_defined_name)
      @prov.set_option(:vm_target_hostname, user_defined_name)
      @prov.set_option(:host_name, user_defined_name)

    # Update instance hostname
    ip_candidate['hostname'] = @prov.get_option(:vm_name).to_s.strip

  elsif ip_candidate['hostname'].present?
    # Use vm_name information from acquired IPAM hostname
    log(:info, "dynamic_hostname <#{dynamic_hostname}> Using IPAM value")
    @prov.set_option(:vm_target_name, ip_candidate['hostname'])
    @prov.set_option(:linux_host_name, ip_candidate['hostname'])
    @prov.set_option(:vm_name, ip_candidate['hostname'])
    @prov.set_option(:vm_target_hostname, ip_candidate['hostname'])
    @prov.set_option(:host_name, ip_candidate['hostname'])
  end

  # Use VLAN information from acquired IPAM entry
  if ip_candidate['vlan'].present?
    # If the workflow specified to use a distributed virtual switch it would be have the value "is_dvs=true"
    # in the ws_values array which was set in CustomizeRequest method
    use_dvs = @ws_values[:is_dvs] || false

    default_vlan = ip_candidate['vlan']
    @prov.set_vlan(default_vlan)

    log(:info, "use_dvs: #{use_dvs}")
    if boolean(use_dvs)
      @prov.set_network_adapter(0, {:network => ip_candidate['vlan'], :is_dvs => true})
    else
      @prov.set_network_adapter(0, {:network => ip_candidate['vlan']})
    end
  end


  # Use IP information from acquired IPAM entry
  if ip_candidate['ipaddr'].present?
    log(:info, "set_nic_settings(vlan)")
    @prov.set_nic_settings(0, {:ip_addr => ip_candidate['ipaddr'], :subnet_mask => ip_candidate['submask'], :gateway => ip_candidate['gateway'], :addr_mode => ["static", "Static"]})
  end


  # Use Storage VLAN information from acquired IPAM
  if ip_candidate['vlan2'].present?
    if boolean(use_dvs)
      log(:info, "set_network_adapter(:network => #{ip_candidate['vlan2']},:is_dvs => true, )")
      @prov.set_network_adapter(1, {:network => ip_candidate['vlan2'], :is_dvs => true})
    else
      log(:info, "set_network_adapter(:network=>#{ip_candidate['vlan2']}) ")
      @prov.set_network_adapter(1, {:network => ip_candidate['vlan2']})
    end
  end


  # Use Storage IP information from acquired IPAM
  if ip_candidate['ipaddr2'].present?
    log(:info, "set_nic_settings(ipaddr2)")
    @prov.set_nic_settings(1, {:ip_addr => ip_candidate['ipaddr2'], :subnet_mask => ip_candidate['submask2'], :addr_mode => ["static", "Static"]})
  end


  # Set date time acquired
  ip_candidate['date_released'] = nil
  ip_candidate['date_acquired'] = Time.now.strftime('%D at %H:%M:%S %p %Z')


  # Update instance and displayname
  if instance_update(ip_candidate_path, ip_candidate)
    # Set Displayname of instance to reflect acquired IP Address
    displayname = "#{ip_candidate['ipaddr']}-#{@prov.get_option(:vm_target_name).to_s.strip}"
    set_displayname(ip_candidate_path, displayname)
  else
    raise "Failed to update instance:<#{ip_candidate_key}>"
  end


  log(:info, "Inspecting Provision object: #{@prov.inspect}")


  #
  # Exit method
  #
  log(:info, "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
###################################
# End of EVM Automate Method: miq_acquire_ip_address
###################################
