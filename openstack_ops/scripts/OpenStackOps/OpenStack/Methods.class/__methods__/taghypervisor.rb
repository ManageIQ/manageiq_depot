#
# Description: Update the instance tags with the hypervisor.
#
# This method assigns a tag to the instance with the name of the
# hypervisor its running on.
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
hypervisor = instance.os_ext_srv_attr_hypervisor_hostname
# tag names can't have dashes, dots, or be longer than 30 chars
shortname  = hypervisor.gsub('-', '_').gsub('.', '_')[0,30]

$evm.log("info", "Found hypervisor #{hypervisor} for VM #{instance.name}")

# Create the category if it doesn't exist
if not $evm.execute('category_exists?', 'hypervisor')
  $evm.log("info", "Creating OpenStack Hypervisor category")
  $evm.execute('category_create',
               :name => 'hypervisor',
               :single_value => false,
               :description => "OpenStack Hypervisor")
end

# Create this tag if it doesn't exist
if not $evm.execute('tag_exists?', 'hypervisor', shortname)
  $evm.log("info", "Creating Hypervisor Tag #{shortname}")
  $evm.execute('tag_create', 'hypervisor',
               :name => shortname,
               :description => hypervisor)
end

if not $evm.execute('tag_exists?', 'hypervisor', shortname)
  $evm.log("error", "Unable to create tag #{shortname}")
end

# Apply the tag
$evm.log("info", "Applying tag hypervisor/#{shortname}")
vm.tag_assign("hypervisor/#{shortname}")

if not vm.tagged_with?('hypervisor', shortname)
  $evm.log("error", "Unable to tag #{vm.name} with hypervisor/#{shortname}")
end
