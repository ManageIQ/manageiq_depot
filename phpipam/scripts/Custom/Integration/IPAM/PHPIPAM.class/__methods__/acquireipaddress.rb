#
# Description : Create a host record in PHPIPAM
# 

@debug = true

require 'httpclient'
require 'json'
require 'base64'
require 'mcrypt'
require 'ipaddr'
require 'ipaddress'

ipam_config = $evm.object['ipam_config']
$evm.log(:info, "PHPIPAM Config : <#{ipam_config}>") if @debug

prov = $evm.root['miq_provision']

vm_target_name = prov.get_option(:vm_target_name)
dns_domain     = "example.com"
subnet_name    = prov.get_option(:vlan)
fqdn           = "#{vm_target_name}.#{dns_domain}"

cipher = Mcrypt.new(:rijndael_256, :ecb, ipam_config[:api_token], nil, :zeros)

http = HTTPClient.new
uri = "http://#{ipam_config[:server]}#{ipam_config[:context]}/api/"

headers = { "Content-Type" => "application/json", "Accept" => "application/json,version=2" }

# Get subnet
request = {
  :controller => 'subnets',
  :action => 'read',
  :desc => subnet_name,
  :format => 'ip'
}
enc_request = cipher.encrypt(request.to_json)
data = {
  :app_id => ipam_config[:api_key],
  :enc_request => Base64.encode64(enc_request)
}

result = JSON.parse(http.get(uri, data, headers).content)
$evm.log(:info, "RESULT : <#{result.inspect}>")
raise "#{result['data']}" unless result['success']
subnet = result['data'].first
$evm.log(:info, "Subnet: #{subnet.inspect}") if @debug

# Get next available IP in subnet
request = {
  :controller => 'addresses',
  :action => 'nextFree',
  :subnetId => subnet['id'],
  :dnsName => "#{vm_target_name}.#{dns_domain}"
}
enc_request = cipher.encrypt(request.to_json)
data = {
  :app_id => ipam_config[:api_key],
  :enc_request => Base64.encode64(enc_request)
}

result = JSON.parse(http.get(uri, data, headers).content)
raise "#{result['data']}" unless result['success']
ip_addr = result['data']['ip_addr']
$evm.log(:info, "IP Address: #{ip_addr}") if @debug

subnet_addr  = subnet['subnet']
subnet_mask  = IPAddress("#{subnet_addr}/#{subnet['mask']}").netmask
subnet_range = IPAddr.new("#{subnet_addr}/#{subnet['mask']}").to_range.to_a
broadcast    = subnet_range.pop
gateway      = subnet_range.pop

prov.set_option(:ip_addr, ip_addr)
prov.set_option(:subnet_addr, subnet_addr)
prov.set_option(:subnet_mask, subnet_mask)
prov.set_option(:gateway, gateway)
prov.set_option(:dns_domain, dns_domain)
prov.set_option(:host_name, fqdn)
prov.set_option(:linux_host_name, fqdn)
prov.set_option(:vm_target_hostname, fqdn)
prov.set_option(:vm_target_name, fqdn)
prov.set_vlan(subnet_name)

## For Vmware w/ static IP
#prov.set_network_adapter(0, {
#  :network  => subnet_name,
#  :is_dvs   => true,
#  :mac_addr => prov.get_option(:mac_address)
#})
#prov.set_network_address_mode('static')
#prov.set_nic_settings(0, {
#  :ip_addr     => ip_addr,
#  :subnet_mask => subnet_mask,
#  :gateway     => gateway.to_s,
#  :dns_domain  => dns_domain,
#  :dns_servers => "192.168.1.102"
#})

$evm.log(:info, "Miq Provision: #{prov.inspect}") if @debug
