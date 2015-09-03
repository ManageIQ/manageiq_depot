#
# Description: <Method description here>
#

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

# Get Miq_Provision, either during provisioning rollback or retirement
prov = $evm.root['miq_provision'] || $evm.root['vm'].miq_provision

cipher = Mcrypt.new(:rijndael_256, :ecb, ipam_config[:api_token], nil, :zeros)

http = HTTPClient.new
uri = "http://#{ipam_config[:server]}#{ipam_config[:context]}/api/"

headers = { "Content-Type" => "application/json", "Accept" => "application/json,version=2" }

# Delete IP address
request = {
  :controller => 'addresses',
  :action => 'delete',
  :ip_addr => prov.get_option(:ip_addr)
}
enc_request = cipher.encrypt(request.to_json)
data = {
  :app_id => ipam_config[:api_key],
  :enc_request => Base64.encode64(enc_request)
}

result = JSON.parse(http.get(uri, data, headers).content)
raise "#{result['errormsg']}" unless result['success']
$evm.log(:info, "#{result['data']['response']}") if @debug
