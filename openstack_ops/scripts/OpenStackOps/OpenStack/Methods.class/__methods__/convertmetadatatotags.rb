#
# Description: Converts Nova Metadata to ManageIQ tags.
#
# This method only assigns tags for categories which already
# exist in MiQ.  This keeps OpenStack users from arbitrarily
# creating new classifications.
#

require 'fog'

vm = $evm.root['vm']
$evm.log("info", "Discovered OpenStack Instance #{vm.inspect}")
$evm.log("info", "UUID #{vm[:ems_ref]}")


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

response = conn.get_server_details(vm.ems_ref)
$evm.log("info", "VM metadata: #{response[:body]['server']['metadata']}")

response[:body]['server']['metadata'].each_pair{|k, v|
  tag_name = k.to_s.downcase.gsub(/\W/, '_')
  if $evm.execute('category_exists?', k)
    $evm.log("info", "Classification category #{k} exists - assigning tag.")
    
    # Create this tag if it doesn't exist
    if $evm.execute('tag_exists?', k, v)
      $evm.log("info", "Tag #{v} exists")
    else
      $evm.log("info", "Creating Tag #{v}")
      $evm.execute('tag_create', k,
                   :name => tag_name,
                   :description => v)
    end
    
    # Apply the tag
    $evm.log("info", "Applying tag #{k}/#{v}")
    vm.tag_assign("#{k}/#{tag_name}")
  else
    $evm.log("info", "Not applying tag for classification #{k}.")
  end
}

