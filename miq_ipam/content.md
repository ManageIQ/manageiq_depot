# TLDR;

# What is this code made for ?

Red Hat CloudForms 3.0 proposed a small IP Address Management (IPAM) module, intended for experimentation in early deployment stages. As it was not part of the core features of a Cloud Management Platform, and because CloudForms could rely on external services, it had been removed from the Automation Engine datastore when ManageIQ was released.

However, Cox Automotive (AKA: AutoTrader Group) had created some extensions to the CloudForms internal IP Address Management (IPAM) module and is now releasing it as an extension to ManageIQ. A robust IPAM system is a core component of push-button automation. The IPAM code has been extended to support many common business needs and is currently being used in AutoTrader.com production.

Cox Automotive has:
 * IPAM feature set:
   * Implemented a reservation token to avoid the race situation of issuing same IP to multiple requests 
   * Code reuse by having all automation workflows call a single method to acquire or release an IP
   * Release of IP if automation workflow fails after it has reserved an IP
   * Email and log warning messages if IPAM is getting low on IPs
   * Email and log error message if IPAM has run out of IPs
   * Write IP reservations counts to the automation log which is reportable via Splunk 
   * Created a tool set to convert IPAM automation XML to a CSV and another script to convert the CSV to a properly formatted MIQ Automation XML file
 * Extensive documentation to:
   * Update schema to include support for more than one NIC per virtual machine
   * Use of tags to acquire and release IPs from correct IPAM


# How do I install / call it ?

First, you have to create IP instances in the IPAM Database. You have to create a CSV file with the following fields:



# In depth explanation

The following image shows an IPAM instance with several of the features being displayed. The fields vlan2 and ipaddr2 are only present if the automation workflow uses dual NIC setup. An additional field is the reserve_token value that is populated when a IP has been reserved. This value is populated with the MIQ request ID value for the provisioning request. This will be discussed in depth further in this document.






The next series of images are of a flowchart detailing some of the logic of the Cox Automotive IPAM extensions. Any workflow that uses the IPAM must have a IPAM tag set to identify which IPAM to use. In the CustomizeRequest method of the workflow, the IPAM tag is set as such:

```ruby
#########  
#  To make the AcquireIPAddress code more universal, moved IPAM DB naming code to the CustomizeRequest.
#  Create the IPAM Database name variable then add as a tag (atg_ipam_path) used for provisioning and retirement
#########
IPAM_name = "IPAM_DB_Z01_ATC_Taxi_Linux"
$evm.log("info","#{@method} - IPAM_name: #{IPAM_name}")
prov.add_tag(:atg_ipam_path, IPAM_name)
```

In the blue boxes of the flowchart, we check to see if the tag has been set properly. This check is done in the /Integration/MIQ_IPAM/IPAM_Methods/ATG_IPAM_Acquire.rb. Any workflows that use the IPAM will use this method.








The blue boxes below display the logic associated with getting an IPAM class, finding all the instances (IP rows) and do some checks of how many are available. It has a couple of email templates used to message with less than 5 IPs or if all IPs have been used.









The example below demonstrates the logic of a user requesting multiple VMs with one provisioning request. The idea is that multiple workers are trying to acquire an IP at the same time. The original IPAM code would issue the same IP to multiple provisioning requests and all but the first would fail when finished provisioning in vCenter.

The boxes in blue represent the logic of each request goes through the same flow, gets the IPs list, finds an available IP, sets it’s MIQ_REQ_ID value as a reserve token. It calls back and get the IP instance it just reserved and confirms the RESERVE_TOKEN field and the MIQ_REQ_ID match. If they don’t match, then there was a race situation and another worker over-wrote (claimed) the IP instance.  Since the values don’t match, this worker will go back an try to find an unused IP.

The ultimate logic is in a race situation, the last worker to write it’s RESERVE_TOKEN value wins the IP.









Once a clean IP is obtained, the ATG_IPAM_Acquire method does a check to see if the workflow uses a dynamic hostname. If dynamic_hostname is false, then the method gets the IP, vlan, hostname and other values from the IPAM and sets them.

If dynamic_hostname is true, then we use the hostname that has been set in the provisioning object. Some business units need the IP and vLan information but want to set their own hostname. This name is usually set in the CustomizeRequest method but also needs to be set in the newly acquired IP instance. This is required due to the logic in the retirement workflows where the retirement release IP method gets the instance by IP and then confirms the hostnames are the same. If not the same, the release IP method will fail.








Need to discuss the Ruby scripts for converting Automate XML into a CSV file. The user edits the CSV and then runs another script to convert the CSV to XML. The XML is properly formatted to be imported into the automate code.
