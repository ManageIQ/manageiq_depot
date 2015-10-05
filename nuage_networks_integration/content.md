# Nuage Networks Integration

Contacts: Manel - david.mendes@ext.produban.com

This method assign a Floating IP to OpenStack VMs working with Nuage Networks.
Is a service post-provisioning method and asks for a Floating IP to each service vm.

Uses the first Enterprise and Domain accessible to the user.

Try to use unassigned Floating IPs from received pool, if there is none, request a one.

Assign the Floating IP to the first VM vPort without Floating IPs.

This method checks for a boolean variable <dialog_floatingip> to ensure it should run.
You can define a Service Catalog checkbox <floatingip> to control the method execution.

## Installation

1. Create an "Automation Class".
* Define on "schema" the next attributes:
 * floatingIPSubnet (Nuage Floating IPs Network Pool ID)
 * organization (Nuage Organization "tenant")
 * password
 * username
 * server (IP or hostname of Nuage API) - note: method uses '"server"/nuage/api/v3_0' as Nuage API path
 * (remember to create an entry to "execute" the "method")
* Create a "Instance" for each Nuage Networks server and fill the attribute values.
* Create a Method with the "nuage_networks_integration.rb" content.
* Add the Instance to the service post-provisioning.
* Create the catalog check-box.
