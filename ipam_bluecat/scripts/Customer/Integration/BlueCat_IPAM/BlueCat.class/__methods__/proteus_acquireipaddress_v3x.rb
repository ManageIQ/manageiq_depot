###################################
#
# EVM Automate Method: Proteus_AcquireIPAddress_v3x
#
# Notes: Calls Proteus to acquire an IP Address during VM provisioning.  This method is used to go against the
#        Proteus version 3.x API.  Use Proteus_AcquireIPAddress for any version 4+ API calls
#        We hope to sunset the one Business unit that has a v3.x instance of Proteus so it has not been updated to
#        use dual NICs.  If needed, use similar logic as the 4+ version of the method.
#
#
###################################

###################################
# Method for logging
###################################
def log(level, message)
  @method = 'Proteus_AcquireIPAddress_v3x'
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
  instance_hash = instance_find("#{search_path}")
  raise "No instances found in <#{search_path.inspect}>" if instance_hash.empty?

  return instance_hash[instance_name]['gateway']
end




begin
  log("info", "==== EVM Automate Method Started =====")

  # Require Savon gem
  gem 'savon', '=1.1.0'
  require 'savon'
  require 'httpi'

  # Configure Savon logging
  Savon.configure do |config|
    config.log = false            # disable logging
    config.log_level = :info      # changing the log level
  end

  # Configure HTTPI logging
  HTTPI.log_level = :info
  HTTPI.log       = false

  # Get provisioning object
  prov = $evm.root["miq_provision"]
  log(:info," - Prov: #{prov.inspect}") if @debug

  # Get parameters
  tags = prov.get_tags
  network_props = tags[:ipam_path].to_s.upcase
  log(:info, " - ipam_path: #{network_props}") if @debug
  raise " Raised exception if <ipam_path> tag is nil" if network_props.nil?

  IPAM_preamble = '/Customer/Integration/BlueCat_IPAM/Network_Lookup/'
  IPAM_path = "#{IPAM_preamble}#{network_props.upcase}"
  log(:info," - IPAM_path: #{IPAM_path}")

  # Set hostname below else use input from model
  hostname = prov.options[:vm_name]
  log(:info," - VMName: #{hostname}") if @debug


  # Get domain from prov instead of setting it from $evm.object
  # Set fqdn
  if prov.options.has_key?(:ws_values)
    ws_values = prov.options[:ws_values]
    dns_domain =  ws_values[:dns_domain]
  end
  sysprep_domain_name = prov.get_option(:sysprep_domain_name)
  log(:info," - sysprep_domain_name: #{sysprep_domain_name.inspect}")

  domain = nil
  domain ||= dns_domain || sysprep_domain_name
  fqdn = "#{hostname}.#{domain}"
  log(:info," - FQDN: #{fqdn}") if @debug

  # Set endpoint below else use input from model
  endpoint = nil
  endpoint ||= $evm.object['endpoint']

  # Set username name below else use input from model
  username = nil
  username ||= $evm.object['username']

  # Set username name below else use input from model
  password = nil
  password ||= $evm.object.decrypt('password')

  # Config ID - ID in proteus for the Parent Configuration object
  container_id = nil
  container_id ||= $evm.object['config_id']

  # DNS ID - ID in Proteus for the DNS default view object
  dns_id = nil
  dns_id ||= $evm.object['dns_id']

  # Set network block below else use input from model
  network = nil
  network ||= get_network(IPAM_path, network_props.upcase)
  log(:info," - Network: #{network}") if @debug

  # Derive subnet mask
  submask = nil
  submask = cidr_to_netmask(network.split('/')[1])
  log(:info," - Submask: #{submask}") if @debug

  # Derive gateway
  gateway = get_gateway(IPAM_path, network_props.upcase)
  gateway ||= get_gateway(IPAM_path, network)
  log(:info," - Gateway: #{gateway}") if @debug

  # Derive vlan
  default_vlan = nil
  default_vlan ||= get_vlan(IPAM_path, network_props.upcase)

  # Set up Savon client
  client = Savon::Client.new do |wsdl, http, wsse|
    wsdl.document = "#{endpoint}/Services/API?wsdl"
    wsdl.endpoint = "#{endpoint}/Services/API"
    http.auth.ssl.verify_mode = :none
  end

  log(:info," - Namespace: #{client.wsdl.namespace.inspect}")
  log(:info," - Endpoint: #{client.wsdl.endpoint.inspect}")
  log(:info, "- Actions: #{client.wsdl.soap_actions}")

  # Log into Proteus
    login_response = client.request :login do
      soap.body = {
          :username => username,
          :password => password,
          :order!    => [:username, :password],
      }
    end
    log(:info," - login: #{login_response.inspect}")  if @debug

  # Set the HTTP Cookie in the headers for all future calls
  client.http.headers["Cookie"] = login_response.http.headers["Set-Cookie"]


  getIPRangedByIP = client.request :get_ip_ranged_by_ip do
    soap.body = {
        :container_id => container_id,
        :address => gateway,
        :type => 'IP4Network'
    }
  end

  getIPRangedByIP_hash = getIPRangedByIP.to_hash[:get_ip_ranged_by_ip_response][:return]
  log(:info, "Get IP Ranged By IP Response: #{getIPRangedByIP_hash.inspect}")

  ip4network_id = getIPRangedByIP_hash[:id]
  log(:info, "IP4Network ID:<#{ip4network_id}>")
  properties_array = getIPRangedByIP_hash[:properties].split('|')
  cidr = properties_array.first
  log(:info, "CIDR:<#{cidr}>")

  getNextIP4Address = client.request :get_next_ip4_address do
    soap.body = {
        :parent_id => ip4network_id,
        :properties => 'excludeDHCPRange=true'
    }
  end
  log(:info, ":get_next_ip4_address response: #{getNextIP4Address.to_hash.inspect}")

  getNextIP4Address_hash = getNextIP4Address.to_hash[:get_next_ip4_address_response][:return]
  new_ipaddr = getNextIP4Address_hash.to_s
  log(:info, "Next IP 4 Address: #{new_ipaddr.inspect}")


  assignIP4Address = client.request :assign_ip4_address do
    soap.body = {
        :configuration_id => container_id,
        :ip4_address => new_ipaddr,
        :mac_address => '',
        :hostInfo => "#{fqdn},#{dns_id},false,false",
        :action => 'MAKE_STATIC',
        :properties => ''
    }
  end

  assignIP4Address_objid = assignIP4Address.to_hash[:assign_ip4_address_response][:return]
  log(:info, "Assigned Next IP 4 Address: #{assignIP4Address_objid.inspect}")

  # Log out of Proteus
  logout_response = client.request :logout
  log(:info, "logout: #{logout_response.inspect}")


  # use dvs
  use_dvs = false
  if prov.options.has_key?(:ws_values)
    ws_values = prov.options[:ws_values]
    use_dvs =  ws_values[:is_dvs]
  end

  if boolean(use_dvs)
    log(:info,"#{@method} ---CAI--- - use_dvs==true")
    prov.set_network_adapter(0, {:network=>default_vlan, :is_dvs => true})
  else
    log(:info,"#{@method} ---CAI--- - use_dvs==false")
    prov.set_network_adapter(0, {:network=>default_vlan})
  end

  # Assign
  #prov.set_nic_settings(0, {:ip_addr=>new_ipaddr, :subnet_mask=>submask, :gateway=>gateway, :addr_mode=>["static", "Static"]})
  prov.set_nic_settings(0, {:ip_addr=>new_ipaddr, :subnet_mask=>submask, :gateway=>gateway, :addr_mode=>["static", "Static"]})
  prov.set_option(:ip_addr, new_ipaddr)
  prov.set_option(:subnet_mask, submask)
  prov.set_option(:gateway, gateway)
  log(:info, "Provision Object update: [:ip_addr=>#{prov.options[:ip_addr].inspect},:subnet_mask=>#{prov.options[:subnet_mask].inspect},:gateway=>#{prov.options[:gateway].inspect},:addr_mode=>#{prov.options[:addr_mode].last.inspect} ]") if @debug

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
# END Of EVM Automate Method: Proteus_AcquireIPAddress_v3x
###################################
