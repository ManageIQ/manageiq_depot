###################################
#
# EVM Automate Method: Proteus_AcquireIPAddress
#
# Notes: Calls Proteus to acquire an IP Address during VM provisioning.  This method has been updated
#        to check for the tag ipam_path and acquire an IP from that vLAN.  It also checks to see
#        if the tag ipam_path2 is present and if so, it will get another IP from that vLAN.  This
#        method is able to get IPs for VMs with 1 or 2 NICs
#
###################################

###################################
# Method for logging
###################################
def log(level, message)
  @method = 'Proteus_AcquireIPAddress'
  @debug = true
  $evm.log(level, "#{@method} - #{message}") if @debug
end

def cidr_to_netmask(cidr)
  require 'ipaddr'
  IPAddr.new('255.255.255.255').mask(cidr).to_s
end

def get_gateway(netcidr)
  require 'ipaddr'
  addr_array = IPAddr.new(netcidr).to_range.to_a
  addr_array[1].to_s
end

def boolean(string)
  return true if string == true || string =~ (/(true|t|yes|y|1)$/i)
  return false if string == false || string.nil? || string =~ (/(false|f|no|n|0)$/i)

  # Return false if string does not match any of the above
  log(:info,"Invalid boolean string:<#{string}> detected. Returning false") if @debug
  return false
end

def instance_find(path)
  result =   $evm.instance_find(path)
  # Returns Hash
  #$evm.log('info',"Instance:<#{path}> properties:<#{result.inspect}>") if @debug
  return result
end

def get_vlan(search_path, instance_name)
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?

  return instance_hash[instance_name]['vlan']
end

def get_network(search_path, instance_name)
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?
  log(:info, " - Look for instance <#{instance_name}> in instance_hash: #{instance_hash.inspect}")

  return instance_hash[instance_name.upcase]['network']
end

def get_gateway(search_path, instance_name)
  log(:info, " ---CAI--- inside of get_gateway() search_path: #{search_path} - instance_name: #{search_path}")
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?

  return instance_hash[instance_name]['gateway']
end


###################################
## This is the meat of the method.  For the front-end NIC, we need to add it to the DNS so we set the hostname field in
## Proteus.  For the storage NIC, we do not want this added to DNS so we don't set the hostname but we do add to the address
## field such that we have a visual queue as to what VM uses the IP
###################################
def get_ip_address(prov, ipam_path, network_props, add_to_dns )
  # Require Savon gem
  gem 'savon', '=1.1.0'
  require 'savon'
  require 'httpi'

  # Configure Savon logging
  Savon.configure do |config|
    config.log = false            # disable logging
    config.log_level = :info      # changing the log level
  end

  # Configure HTTPI gem
  HTTPI.log_level = :info # changing the log level
  HTTPI.log       = false # diable HTTPI logging
  HTTPI.adapter   = :net_http # [:httpclient, :curb, :net_http]

  # Set hostname below else use input from model
  hostname = prov.options[:vm_name]
  log(:info," - VMName: #{hostname}") if @debug


  # Get domain from prov instead of setting it from $evm.object
  # Set fqdn
  domain = 'autotrader.com'
  domain ||= prov.get_option(:dns_domain) || $evm.object['domain']
  fqdn = "#{hostname}.#{domain}"
  log(:info," - FQDN: #{fqdn}") if @debug

  # Set endpoint below else use input from model
  endpoint = nil
  endpoint ||= $evm.object['endpoint']

  # Set password name below else use input from model
  password = nil
  password ||= $evm.object.decrypt('password')

  # Set username name below else use input from model
  username = nil
  username ||= $evm.object['username']

  # Config ID
  config_id = nil
  config_id ||= $evm.object['config_id']

  # DNS ID - ID in Proteus for the DNS default view object
  dns_id = nil
  dns_id ||= $evm.object['dns_id']

  network = nil
  network ||= get_network(ipam_path, network_props.upcase)
  log(:info," - Network: #{network}") if @debug

  submask = nil
  submask = cidr_to_netmask(network.split('/')[1])
  log(:info," - Submask: #{submask}") if @debug

  gateway = nil
  gateway ||= get_gateway(ipam_path, network_props.upcase)
  log(:info," - Gateway: #{gateway}") if @debug

  default_vlan = nil
  default_vlan ||= get_vlan(ipam_path, network_props.upcase)

  # Set up Savon client
  client = Savon::Client.new do |wsdl, http, wsse|
    wsdl.document = "#{endpoint}/Services/API?wsdl"
    wsdl.endpoint = "#{endpoint}/Services/API"
    http.auth.ssl.verify_mode = :none
  end

  log(:info," - Namespace: #{client.wsdl.namespace.inspect}")
  log(:info," - Endpoint: #{client.wsdl.endpoint.inspect}")
  #  log(:info, "- Actions: #{client.wsdl.soap_actions}")

  # Log into Proteus
  begin
    login_response = client.request :login do
      soap.body = {
          :username => username,
          :password => password,
          :order!   => [:username, :password],
      }
    end
    log(:info," - login: #{login_response.inspect}")  if @debug
  end

  # Set the HTTP Cookie in the headers for all future calls
  client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]

  search_result = client.request :search_by_object_types do
    soap.body = {
        :keyword => network, # ex, '10.226.131.0/24'
        :types => 'IP4Network',
        :start => 0,
        :count => 1,
        :order! => [:keyword, :types, :start, :count]
    }
  end

  search_result_hash = search_result.to_hash[:search_by_object_types_response][:return][:item]
  $evm.log("info","#{@log_prefix} - Search By Object Types Response: #{search_result_hash.inspect}") if @debug
  $evm.log("info","#{@log_prefix} - Network ID: #{search_result_hash[:id]}") if @debug

  # Vlan ID
  properties_hash = Hash.new
  search_result_hash[:properties].split('|').each { |prop|
    properties_hash[prop.split('=')[0]] = prop.split('=')[1]
  }
  vlan_id = properties_hash['VlanID']
  $evm.log("info","#{@log_prefix} - VLAN ID: #{properties_hash['VlanID']}") if @debug

  # View ID
  view_id =  properties_hash['defaultView']

  ## For storage IPs, we don't want to set the hostname in Proteus because we have a auto-push of any DNS records
  if boolean(add_to_dns)
    host_name_info = "#{fqdn},#{view_id},false,false"
    address_name = nil
  else
    host_name_info = ""
    address_name = "name=#{hostname}"
  end

  assign_result = client.request :assign_next_available_ip4_address do
    soap.body = {
        :configuration_id => config_id,
        :parent_id => search_result_hash[:id],
        :macAddress => '',
        :hostInfo => "#{host_name_info}",
        :action => 'MAKE_STATIC',
        :properties => "#{address_name}",
        :order! => [:configuration_id, :parent_id, :macAddress, :hostInfo, :action, :properties]
    }
  end

  assign_result_hash = assign_result.to_hash[:assign_next_available_ip4_address_response][:return]
  $evm.log("info","#{@log_prefix} - Assign Next Available IP Response: #{assign_result_hash.inspect}") if @debug

  # new ipaddr
  properties_hash = Hash.new
  assign_result_hash[:properties].split('|').each { |prop|
    properties_hash[prop.split('=')[0]] = prop.split('=')[1]
  }

  new_ipaddr = properties_hash['address']
  $evm.log("info","#{@log_prefix} - Assigned IP: #{new_ipaddr}") if @debug

  # Log out of Proteus
  logout_response = client.request :logout
  log(:info," - logout: #{logout_response.inspect}") if @debug

  return new_ipaddr
end



#######################################################################################################
# End of Methods
#######################################################################################################
begin
  log("info", "==== EVM Automate Method Started =====")

  # Get provisioning object
  prov = $evm.root["miq_provision"]
  log(:info," - Prov: #{prov.inspect}") if @debug

  # Get parameters
  tags = prov.get_tags

  ## Get the IPAM tag from the prov object - this tag was set in the CustomizeRequest method
  network_props = tags[:ipam_path].to_s.upcase
  log(:info, " - ipam_path: #{network_props}") if @debug
  raise " Raised exception if <ipam_path> tag is nil" if network_props.nil?

  IPAM_preamble = '/Customer/Integration/BlueCat_IPAM/Network_Lookup/'
  IPAM_path = "#{IPAM_preamble}#{network_props.upcase}"
  log(:info," - IPAM_path: #{IPAM_path}")


  hostname = prov.options[:vm_name]
  ## Call to get the first IP
  new_ipaddr = get_ip_address(prov, IPAM_path, network_props, true)
  log(:info," ---CAI--- Set IP Address: #{new_ipaddr} - #{hostname} ---CAI---")


  ######
  ## If the VM will have a dual NIC setup, the CustomizeRequest method would have added an ipam_path2 variable
  ######
  network_props2 = tags[:ipam_path2].to_s.upcase
  unless network_props2.to_s == ''
    is_2nic = true
    log(:info, " ---CAI--- Second NIC flag set.  ipam_path2: #{network_props2}") if @debug
    IPAM_path2 = "#{IPAM_preamble}#{network_props2.upcase}"
    log(:info," ---CAI---  Full Path for second NIC IPAM_path2: #{IPAM_path2}")
    default_vlan2 = get_vlan(IPAM_path2, network_props2.upcase)
    gateway2 =  get_gateway(IPAM_path2, network_props2.upcase)
    network2 = get_network(IPAM_path2, network_props2.upcase)
    submask2 = cidr_to_netmask(network2.split('/')[1])

    new_ipaddr2 = get_ip_address(prov, IPAM_path2, network_props2, false)
    log(:info,"---CAI--- Set IP Address: #{new_ipaddr2} - #{hostname} (Storage) ---CAI---")
  end




  # use Distributed Virtual Switch - As some data center use the DVS, we set this tag/flag in the customize request
  use_dvs = false
  if prov.options.has_key?(:ws_values)
    ws_values = prov.options[:ws_values]
    use_dvs =  ws_values[:is_dvs]
  end

  default_vlan = get_vlan(IPAM_path, network_props.upcase)
  gateway =  get_gateway(IPAM_path, network_props.upcase)
  network = get_network(IPAM_path, network_props.upcase)
  submask = cidr_to_netmask(network.split('/')[1])

  if boolean(use_dvs)
    if boolean(is_2nic)
      log(:info,"#{@method} ---CAI--- Dual NIC with use_dvs==true")
      default_vlan2 = get_vlan(IPAM_path2, network_props2.upcase)
      prov.set_network_adapter(0, {:network=>default_vlan, :is_dvs => true})
      prov.set_network_adapter(1, {:network=>default_vlan2, :is_dvs => true})
      prov.set_option(:network_adapters, [2, "2"] )
    else
      log(:info,"#{@method} ---CAI--- Single NIC with use_dvs==true")
      prov.set_network_adapter(0, {:network=>default_vlan, :is_dvs => true})
      prov.set_option(:network_adapters, [1, "1"] )
    end
  else
    if boolean(is_2nic)
      log(:info,"#{@method} ---CAI--- Dual NIC with use_dvs==false")
      default_vlan2 = get_vlan(IPAM_path2, network_props2.upcase)
      prov.set_network_adapter(0, {:network=>default_vlan})
      prov.set_network_adapter(1, {:network=>default_vlan2})
      prov.set_option(:network_adapters, [2, "2"] )

    else
      log(:info,"#{@method} ---CAI--- Single NIC with use_dvs==false")
      prov.set_network_adapter(0, {:network=>default_vlan})
      prov.set_option(:network_adapters, [1, "1"] )
    end
  end


  prov.set_option(:ip_addr, new_ipaddr)
  prov.set_option(:subnet_mask, submask)
  prov.set_option(:gateway, gateway)
  prov.set_nic_settings(0, {:ip_addr=>new_ipaddr.to_s, :subnet_mask=>submask.to_s, :gateway=>gateway.to_s, :addr_mode=>["static", "Static"]})
  log(:info, "Provision Object update: NIC 0 [:ip_addr=>#{new_ipaddr},:subnet_mask=>#{submask},:gateway=>#{gateway},:addr_mode=>'static', 'Static' ]") if @debug

  if boolean(is_2nic)
    prov.set_nic_settings(1, {:ip_addr=>new_ipaddr2.to_s, :subnet_mask=>submask2.to_s, :gateway=>gateway2.to_s, :addr_mode=>["static", "Static"]})
    log(:info, "Provision Object update: NIC 1 [:ip_addr=>#{new_ipaddr2},:subnet_mask=>#{submask2},:gateway=>#{gateway2},:addr_mode=>'static', 'Static' ]" ) if @debug
  end


  $evm.log("info", "#{@method} Exit Proteus_AcquireIPAddress2nic: Inspecting Provision object: #{prov.inspect}")
  #######  ########  ########  ########
  #    $evm.log("info", "Before Manual Raise - Inspecting Provision object: #{prov.inspect}")
  #    raise "#{@method} ---CAI--- ---CAI--- Manually Raise exception ---CAI--- ---CAI---"
  #######  ########  ########  ########



  #
  # Exit method
  #
  log(:info, " - EVM Automate Method Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  $evm.log("error", " - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
###################################
# End of EVM Automate Method: Proteus_AcquireIPAddress
###################################
