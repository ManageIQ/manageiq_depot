#
# Description: Example method which verifies that a particular
# metadata tag exists.  In this example, we're checking for
# the tag "localization".  If the tag doesn't exist, we stop
# the instance.
#

require 'fog'

vm = $evm.root['vm']
$evm.log("info", "Discovered OpenStack Instance #{vm.inspect}")

openstack = vm.ext_management_system
auth_url = "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens"

begin
  conn = Fog::Compute.new({
    :provider => 'OpenStack',
    :openstack_api_key  => openstack.authentication_password,
    :openstack_username => openstack.authentication_userid,
    :openstack_auth_url => auth_url,
    :openstack_tenant   => "admin"
  })
rescue => connerr
  $evm.log("error", "Couldn't connect to Openstack with provider credentials")
end

response = conn.get_server_details(vm.ems_ref)
$evm.log("info", "VM metadata: #{response[:body]['server']['metadata']}")

localization = nil

response[:body]['server']['metadata'].each_pair{|k, v|
  if k == "localization"
    localization = v
  end
}

if localization.nil?
  $evm.log("info", "Stopping VM without localization set: #{vm.name}")
  vm.suspend
end

