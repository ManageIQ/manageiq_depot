###################################
#
# EVM Automate Method: proteus_releaseipaddress
#
# Notes: Calls Proteus to release an IP Address during VM deprovisioning.  This works for either the v3.x or v4.x
#        methods to acquire an IP.  This was created for a hybrid IPAM environment and the request was routed from
#        the method release_ip_address_router
#
# Inputs: prov
#
###################################

###################################
# Method for logging
###################################
def log(level, message)
  @method = 'proteus_releaseipaddress'
  @debug = true
  $evm.log(level, "#{@method} - #{message}") if @debug
end


###################################
# Method for releasing the IP(s)
###################################
def release_ip(ip_addr, config_id, client)

  ip4address_result = client.request :get_ip4_address do
    soap.body = {
        :container_id => config_id,
        :address => ip_addr,
        :order! => [:container_id, :address]
    }
  end
  #log(:info, " Inspecting ip4address_result: #{ip4address_result.inspect}")

  ip4address_id = ip4address_result.to_hash[:get_ip4_address_response][:return][:id]
  log(:info, " --CAI-- Attempting to delete_device_instance:  With ID: #{ip4address_id.inspect}")
  delete_result = client.request :delete do
    soap.body = {
        :object_id => ip4address_id
    }
  end
  #log(:info, " - delete_result: #{delete_result.inspect}") if @debug
end


###################################
# Start of content
###################################
begin
  log(:info, "  - EVM Automate Method Started")

  # Require Savon gem
  gem 'savon', '=1.1.0'
  require 'savon'

  # Configure Savon logging
  Savon.configure do |config|
    config.log = false # disable logging
    config.log_level = :info # changing the log level
  end

  # Configure HTTPI logging
  HTTPI.log_level = :info
  HTTPI.log = false

  # Set endpoint below else use input from model
  endpoint = nil
  endpoint ||= $evm.object['endpoint']

  # Set username name below else use input from model
  username = nil
  username ||= $evm.object['username']

  # Set username name below else use input from model
  password = nil
  password ||= $evm.object.decrypt('password')

  # Config ID
  config_id = nil
  config_id ||= $evm.object['config_id']

  # Set up Savon client
  client = Savon::Client.new do |wsdl, http, wsse|
    wsdl.document = "#{endpoint}/Services/API?wsdl"
    wsdl.endpoint = "#{endpoint}/Services/API"
    http.auth.ssl.verify_mode = :none
  end

  log(:info, "  - Namespace: #{client.wsdl.namespace.inspect}")
  log(:info, "  - Endpoint: #{client.wsdl.endpoint.inspect}")

  # Log into Proteus
  login_response = client.request :login do
    soap.body = {
        :username => username,
        :password => password,
        :order! => [:username, :password]
    }
  end
  #log(:info, "  - login: #{login_response.inspect}") if @debug

  # Set the HTTP Cookie in the headers for all future calls
  client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]

  # Get current VM object
  vm = $evm.root['vm']
  raise "#{@method} VM Object not found and cannot release IP" if vm.nil?

  # # # #
  #  Check to see if the VM has one or two NIC and release each from Proteus
  # # # #
  vm.ipaddresses.each do |ip_address|
    log(:info, "--CAI-- Release IP for VM Name: #{vm.name} with IP Address: #{ip_address}")
    release_ip(ip_address, config_id, client)
  end


  # Log out of Proteus
  logout_response = client.request :logout
  #log(:info, "  - logout: #{logout_response.inspect}") if @debug

  #
  # Exit method
  #
  log(:info, "  - EVM Automate Method Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  log(:error, " - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
