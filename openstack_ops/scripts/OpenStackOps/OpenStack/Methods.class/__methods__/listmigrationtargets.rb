#
# Description: Retrieve a list of possible migration targets for a virtual
# instance.
#
# This method checks with Nova for a list of available migration targets 
# within an instance's Availability Zone and populates a dynamic dialog
# dropdown with the list.
#

require 'fog'

vm = $evm.root['vm']

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
current_hypervisor = instance.os_ext_srv_attr_hypervisor_hostname

hypervisor_list = {}
conn.hosts.each do |host|
  if host.service_name == "compute"
    # First exclude the current hypervisor
    if host.host_name != current_hypervisor
      # Then check the AZ
      $evm.log("info", "Comparing #{host.zone} to #{vm.availability_zone.name}")
      if host.zone == vm.availability_zone.name
        hypervisor_list[host.host_name] = host.host_name
      end
    end
  end
end

if hypervisor_list.length == 0
  hypervisor_list["none"] = "none"
end

dialog_field = $evm.object

# sort_by: value / description / none
dialog_field["sort_by"] = "value"

# sort_order: ascending / descending
dialog_field["sort_order"] = "ascending"

# data_type: string / integer
dialog_field["data_type"] = "integer"

# required: true / false
# dialog_field["required"] = "true"

dialog_field["values"] = hypervisor_list
dialog_field["default_value"] = hypervisor_list.keys[0]
