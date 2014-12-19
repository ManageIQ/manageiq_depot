#
# Description: Live Migrate an Instance to the hypervisor specified in dialog_TargetHypervisor
#

require 'fog'

vm = $evm.root['vm']
target_hypervisor = $evm.root['dialog_TargetHypervisor']

$evm.log("info", "Got request to migrate #{vm.name} to #{target_hypervisor}")

openstack = vm.ext_management_system

auth_url = "http://#{openstack[:hostname]}:#{openstack[:port]}/v2.0/tokens"

# TODO: This should be scoped to the tenant of the virtual machine
# instance and not "admin"
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


instance   = conn.servers.get(vm.ems_ref)
begin
  instance.live_migrate(target_hypervisor, false, false)
rescue => migrateerr
  $evm.log("error", "Failed to migrate VM #{migrateerr}")
end

