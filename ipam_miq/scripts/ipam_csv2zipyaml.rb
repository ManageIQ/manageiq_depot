############
## Ruby command line script to convert an CSV Input File into a properly formated zip file for import into Automation.
## This script will build the IPAM schema based on the CSV's header row (first line) and build the instances accordingly.
## The output zip can be imported into automation code in the MIQ/CloudForm UI at Automate=>Import/Export.
## @author: JD Calder   @company: Cox Automotive Inc.    @date: 05/17/15
############
require 'csv'
require 'fileutils'
require 'rubygems'
require 'zip'


########
##  The following directory array will define the directory structure for creating the zip file and will inport
##  the corresponding data structure into the automate model in MIQ/CF.  Add to or change this array to match your
##  directory structure.
########
# Build the array for each node of the tree stucture:
# The follow array equates to /Customer/Integration/MIQ_IPAM/Network_Lookup/your/directory/structure
#directory = [ "Customer", "Integration", "MIQ_IPAM", "Network_Lookup", "your", "directory", "structure" ]
directory = [ "Customer", "Integration", "MIQ_IPAM", "Network_Lookup" ]


########
##  Method to Zip the directory and all the included files
########
def compress(ipam_name)
  domain_dir = "temp/"
  zipfile_name = "#{ipam_name}.zip"
  Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
    #puts "trying to compress #{domain_dir}"
    Dir[File.join(domain_dir, '**', '*')].each do |file|
      #puts "add to zip #{zipfile_name}:  #{file}"
      zipfile.add(file.sub(domain_dir, ''), file)
    end
  end
  puts "\n\n ** Zip file created as #{zipfile_name}"
end

########
##  Method to clean up the temporary directory structure once it has been zipped.
########
def cleanup_temp_files
  FileUtils.rm_rf("temp")
end


########
##  Get input file name from user.  Get the name of the IPAM class from the user
########
print "CSV file to read: "
input_file = gets.chomp

print "IPAM Output name: "
ipam_name_temp = gets.chomp
ipam_name = "#{ipam_name_temp}.class"

## Create the directory structure on your system
file_path = "temp"
for i in 0..(directory.size - 1)
  file_path += "/#{directory[i]}"
end
#puts "file_path = #{file_path}"

## The following command will create the actual directory structure
puts "\nCreating file structure for #{file_path}/#{ipam_name}"
FileUtils.mkdir_p("#{file_path}/#{ipam_name}")

########
##  For the MIQ/CF import to work properly, the parent directory must have a domain yaml file and each child must have
##  a corresponding namespace yaml file.  This next section will create these regardless of the depth of the directory
##  structure based on the directory array defined at the top of this script.
########
## Now we need to create the Domain file with the first element in the directory array
domain_path = "temp/#{directory[0]}/__domain__.yaml"
File.open(domain_path, 'w') do |file|
  file.puts "---"
  file.puts "object_type: domain"
  file.puts "version: 1.0"
  file.puts "object:"
  file.puts "  attributes:"
  file.puts "    name: #{directory[0]}"
  file.puts "    description:"
  file.puts "    display_name:"
  file.puts "    system:"
  file.puts "    priority: 4"
  file.puts "    enabled: true"
  file.close
end

## Now we need to create the all the Namespace files properly embedded in their parents starting with second
## element in the directory array
for i in 1..(directory.size - 1)
  directory_depth = 1
  directory_path = "temp/#{directory[0]}"   ## Set the domain directory and then add to it as we progress downward

  ## Build the path to the proper depth of the directory in focus
  while directory_depth <= i  do
    directory_path += "/#{directory[directory_depth]}"
    directory_depth +=1
  end
  #puts "directory_path = #{directory_path}"

  ## Now we need to create all the Namespace files properly embedded in their parents
  namespace_path = "#{directory_path}/__namespace__.yaml"
  File.open(namespace_path, 'w') do |file|
    file.puts "---"
    file.puts "object_type: namespace"
    file.puts "version: 1.0"
    file.puts "object:"
    file.puts "  attributes:"
    file.puts "    name: #{directory[i]}"
    file.puts "    description:"
    file.puts "    display_name:"
    file.puts "    system:"
    file.puts "    priority:"
    file.puts "    enabled:"
    file.close
  end ## end of File.open
end ## end of for loop



########
##  Now we'll start looking at parsing the CSV file and creating the individual IP Address yaml instances
########
csv = CSV::parse(File.open(input_file) { |f| f.read })

## Get the CSV header row to know how many fields we have and look for a couple of required fields (inuse, ipaddr and hostname)
header_names = csv.shift
num_fields = header_names.size
## Create a hash of the header array to easily find the index for our targeted fields
index_hash = Hash[header_names.map.with_index.to_a]
#puts "There are #{num_fields} Header Names:  #{header_names} - inuse field is index #{index_hash['inuse']}"

inuse_index = index_hash['inuse']
ipaddr_index = index_hash['ipaddr']
hostname_index = index_hash['hostname']


#######
##   Create each IP instance (yaml file) from the CSV file
#######
csv.each do |record|
  output_file = "#{file_path}/#{ipam_name}/#{record[ipaddr_index]}.yaml"
  #puts "Writing file ... #{output_file}"
  File.open(output_file, 'w') do |f|
    f.puts "---"
    f.puts "object_type: instance"
    f.puts "version: 1.0"
    f.puts "object:"
    f.puts "  attributes:"
    ## update the display name if the IP is in use to give visual queue of used & available IPs
    if record[inuse_index] =~ (/(true|t|yes|y|1)$/i)
      f.puts "    display_name: #{record[ipaddr_index]}-#{record[hostname_index]}"
    else
      f.puts "    display_name:"
    end
    f.puts "    name: #{record[ipaddr_index]}"
    f.puts "    inherits:"
    f.puts "    description:"
    f.puts "  fields:"
    for i in 0..(num_fields - 1)
      f.puts "  - #{header_names[i]}:"
      f.puts "      value: '#{record[i]}'"
    end
    f.close
  end # End file block - close file
end
#puts "Contents of #{input_file} written as multiple YAML files."



schema_name = "#{file_path}/#{ipam_name}/__class__.yaml"
## Now we need to output the IPAM schema file
File.open(schema_name, 'w') do |file|
  file.puts "---"
  file.puts "object_type: class"
  file.puts "version: 1.0"
  file.puts "object:"
  file.puts "  attributes:"
  file.puts "    description:"
  file.puts "    display_name:"
  file.puts "    name: #{ipam_name_temp}"
  file.puts "    type:"
  file.puts "    inherits:"
  file.puts "    visibility:"
  file.puts "    owner:"
  file.puts "  schema:"
  ## Loop thru the header file and create an entry for each field
  for i in 0..(num_fields - 1)
    file.puts "  - field:"
    file.puts "      aetype: attribute"
    file.puts "      name: #{header_names[i]}"
    file.puts "      display_name:"
    file.puts "      datatype: string"
    file.puts "      priority: #{i+1}"
    file.puts "      owner:"
    file.puts "      default_value:"
    file.puts "      substitute: true"
    file.puts "      message: create"
    file.puts "      visibility:"
    file.puts "      collect:"
    file.puts "      scope:"
    file.puts "      description:"
    file.puts "      condition:"
    file.puts "      on_entry:"
    file.puts "      on_exit:"
    file.puts "      on_error:"
    file.puts "      max_retries:"
    file.puts "      max_time:"
  end
  file.close
end

########
## Now we will compress the directory of IPAM yaml files and the schema file into a single zip
########
compress(ipam_name)
## You can comment out the following like if you want to confirm the content prior to zipping the directory
cleanup_temp_files()

## CSV Example
# vlan,hostname,ipaddr,submask,gateway,inuse,vlan2,ipaddr2,submask2,date_released,date_acquired,reserve_token
# VMNET_10.11.11.X,dlab0030,10.11.11.30,255.255.255.0,10.11.11.1,FALSE,VMNET_172.45.54.X,172.45.54.30,,,,
# VMNET_10.11.11.X,dlab0031,10.11.11.31,255.255.255.0,10.11.11.1,FALSE,VMNET_172.45.54.X,172.45.54.31,,,,
# VMNET_10.11.11.X,dlab0032,10.11.11.32,255.255.255.0,10.11.11.1,FALSE,VMNET_172.45.54.X,172.45.54.32,,,,
# VMNET_10.11.11.X,dlab0033,10.11.11.33,255.255.255.0,10.11.11.1,FALSE,VMNET_172.45.54.X,172.45.54.33,,,,
# VMNET_10.11.11.X,dlab0034,10.11.11.34,255.255.255.0,10.11.11.1,FALSE,VMNET_172.45.54.X,172.45.54.34,,,,
# VMNET_10.11.11.X,dlab0035,10.11.11.35,255.255.255.0,10.11.11.1,TRUE,VMNET_172.45.54.X,172.45.54.35,,,7/9/15 3:45 PM,1000000000264
# VMNET_10.11.11.X,dlab0036,10.11.11.36,255.255.255.0,10.11.11.1,TRUE,VMNET_172.45.54.X,172.45.54.36,,,7/9/15 5:17 PM,1000000000269


## IP Address YAML output example
