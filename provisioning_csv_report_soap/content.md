Example script using the SOAP API to gather some information about provisioned VMs to create a CSV file.

SOAP is going away, but until REST has complete feature parity, this might be useful.

I call this from cron as:

scl enable ruby193 /path/to/provisioning_csv_report_soap.rb
