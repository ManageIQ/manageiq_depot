#!/usr/bin/env ruby
# This script will generate a CSV for all VMs provisioned the previous day
# Some fields can be controlled via the /etc/config.ini file
# * organization
# * apiuser
# * apipass
# * apiwsdl
# * notifyfrom
# * notifyaddr 
#
# Author:: Matt Hyclak (mailto:matt.hyclak@cbts.net)

require 'inifile'
require 'json'
require 'mail'
require 'savon'
require 'tempfile'

# Create the CVS file
csvtemp = Tempfile.new('csvtemp')

# Read the configuration file, or create an empty array if missing
configfilepath = '/etc/config.ini'
configfile = IniFile.load(configfilepath)
configdata = configfile['CloudForms'] || {}

# Set some sane defaults
organization = configdata['organization'] || ARGV[0] || 'Unknown Customer'
apiuser = configdata['apiuser'] || 'admin'
apipass = configdata['apipass'] || 'smartvm'
apiwsdl = configdata['apiwsdl'] || 'http://localhost:3000/vmdbws/wsdl'
notifyfrom = configdata['notifyfrom'] || 'cloudforms@example.com'
notifyaddr = configdata['notifyaddr'] || 'reports@example.com'

# Create some useful variables
yesterday = DateTime.now() - 1
vmcount = 0

# Create the CSV Header and put in the temp file
csv_header = "Search code,IP Address,Name,OS,Organization name,Datacenter,Physical Device Address,Management Type,Brand,Model,Serial Number,Requestor,Primary Customer Contact,Secondary Customer Contact,Contract_ID,Gold_Managed,Silver_Managed,Self_Managed,Monitor_Only,Billable\n"
csvtemp << csv_header

# Make the SOAP connection to the configured server
client = Savon.client(basic_auth: [apiuser, apipass], wsdl: apiwsdl, log: false)

# Get the list of all VMs
response = client.call(:get_vm_list, message: {hostGuid: '*'})
vmlist = response.to_hash[:get_vm_list_response][:return][:item]

# Iterate over each VM, gathering information and writing it out if necessary
vmlist.each do |vmhash|
  # Get the data for the VM
  response = client.call(:find_vm_by_guid, message: {vmGuid: vmhash[:guid]})
  vmdata = response.to_hash[:find_vm_by_guid_response][:return]

  # Define the data we need to keep
  name = vmdata[:name]
  created_on = vmdata[:created_on]
  operatingsystem = vmdata[:hardware][:guest_os_full_name]
  search_code = ""
  billable = ""
  contractid = ""
  monitoronly = ""
  selfmanaged = ""
  silvermanaged = ""
  goldmanaged = ""
  ipaddress = ""
  owner = ""
  address = ""
  datacenter = ""

  # Only process VMs created yesterday
  if created_on.strftime('%Y-%m-%d') == yesterday.strftime('%Y-%m-%d') then

    # Start with the custom attributes - this contains VC and CF attributes
    customattrs = vmdata[:custom_attributes][:item]
    if customattrs.is_a? Array
      customattrs.each do |customattr|
        case customattr[:name]
        when 'search_code'
          search_code = customattr[:value]
        when 'Billable'
          billable = customattr[:value]
        when 'Contract_ID'
          contractid = customattr[:value]
        when 'Monitor_Only'
          monitoronly = customattr[:value]
        when 'Self_Managed'
          selfmanaged = customattr[:value]
        when 'Silver_Managed'
          silvermanaged = customattr[:value]
        when 'Gold_Managed'
          goldmanaged = customattr[:value]
        end
      end
    end

    # Collect additional attributes
    vmdata[:ws_attributes][:item].each do |wsattr|
      case wsattr[:name]
      when 'ipaddresses'
        ipaddress = wsattr[:value]
      when 'evm_owner_name'
        owner = wsattr[:value]
      end
    end

    # Catch missing IP addresses
    if ipaddress.is_a? Hash
      ipaddress = 'MISSING'
    end

    # If multiple IP addresses exist, a | delimited string is returned
    # Right now we are not providing a way to add additional NICs
    # If/when we have any VM templates with multiple NICs, this will need
    # to be addressed.

    # Collect tags
    tagresponse = client.call(:vm_get_tags, message: {vmGuid: vmdata[:guid]})
    tags = tagresponse.to_hash[:vm_get_tags_response][:return][:item]

    # Iterate over tags and find the ones we're interested in
    tags.each do |tag|
      case tag[:category]
      when "location"
        location = tag[:tag_name]
      end

      # Create a few more variables from the location tag.
      case location
      when "useast"
        datacenter = "US East"
        address = "123 Sesame St New York NY 12345"
      when "uswest"
        datacenter = "US West"
        address = "456 Electric Ave Los Angeles CA 98765"
      end
    end

    if search_code != ''
      csvtemp << "#{search_code},#{ipaddress},#{name},#{operatingsystem},#{organization},#{datacenter},#{address},Managed,VMWare,VMware,VMware,#{owner},,,#{contractid},#{goldmanaged},#{silvermanaged},#{selfmanaged},#{monitoronly},#{billable}\n"
      # Increment the counter for the e-mail message
      vmcount += 1
    end
  end
end

# Close the file. Don't unlink so we can archive it.
csvtemp.close

# Create the archive directory if it doesn't exist
if not File.exists?('/root/provisioned') then Dir.mkdir('/root/provisioned') end

# Keep an archive named with the Org and Date by renaming the tempfile
csvfilename = "CloudForms Provisioned VMs for #{organization} #{yesterday.strftime('%Y-%m-%d')}.csv"
File.rename(csvtemp.path, "/root/provisioned/#{csvfilename}")

# Send mail with the CSV attached. Don't delete the CSV just in case.
mail = Mail.new do
  from     notifyfrom
  to       notifyaddr
  subject  "CloudForms - #{organization} - Provisioned VMs for #{yesterday.strftime('%Y-%m-%d')}"
  body     "There were #{vmcount} VMs provisioned. See attachment for details."
  add_file :filename => csvfilename, :content => File.read("/root/provisioned/#{csvfilename}")
end

# Only send the mail if we provisioned at least one VM
if vmcount > 0 then mail.deliver! end
