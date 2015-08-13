#####
## Ruby command line script to convert an CSV Input File into a properly formated XML for import into Automation.
## This script will build the IPAM schema based on the CSV's header row (first line) and build the instances accordingly.
## The output XML can be imported into automation code in the CloudForm UI at Automate=>Import/Export.
## @author: JD Calder   @company: Cox Automotive Inc.    @date: 09/16/14
#####
require 'csv'


print "CSV file to read: "
input_file = gets.chomp
print "File to write XML to: "
output_file = gets.chomp
print "IPAM Name: "
ipam_filename = gets.chomp
csv = CSV::parse(File.open(input_file) {|f| f.read} )
fields = csv.shift
puts "Writing XML..."
File.open(output_file, 'w') do |f|
  f.puts '<?xml version="1.0" encoding="UTF-8"?>'
  f.puts '<MiqAeDatastore version="1.0">'
  f.puts "  <MiqAeClass name='#{ipam_filename}' namespace='Integration/MIQ_IPAM'>"
  f.puts "    <MiqAeSchema> "
  for i in 0..(fields.length - 1)
    f.puts "      <MiqAeField name='#{fields[i]}' substitute='true' aetype='attribute' datatype='string' priority='#{i+1}' message='create'></MiqAeField> "
  end
  f.puts "    </MiqAeSchema> "
     csv.each do |record|
    if record[5].downcase == "true"
      f.puts "   <MiqAeInstance name='#{record[2]}' display_name='#{record[2]}-#{record[1]}'>"
    else
      f.puts "   <MiqAeInstance name='#{record[2]}'>"
    end
    for i in 0..(fields.length - 1)
      f.puts "    <MiqAeField name='#{fields[i]}'> #{record[i]} </MiqAeField>"
    end
    f.puts "   </MiqAeInstance>"
  end
  f.puts '  </MiqAeClass>'
  f.puts '</MiqAeDatastore>'
end # End file block - close file
puts "Contents of #{input_file} written as XML to #{output_file}."
