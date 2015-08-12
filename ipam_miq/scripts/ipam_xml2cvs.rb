require 'nokogiri'
require 'csv'
require 'date'

#####
## Ruby command line script to parse an XML Input File from Automation Export
## which was cleaned to only contain the MiqAeInstance.  It will parse the content data
## and output into a CSV file.  Stripped out commas in the date fields so could output and import into IPAM.
## @author: JD Calder   @company: Cox Automotive Inc.    @date: 03/24/14
#####

puts " * * * START OF RUBY SCRIPT * * *\n"

print "XML input filename: "
input_file = gets.chomp
print "CSV output filename: "
output_file = gets.chomp

@doc = Nokogiri::XML(File.open(input_file))
output = File.open(output_file, "wb")

####
## Get the schema node and print out the names of the fields
####
schema = @doc.xpath("//MiqAeClass//MiqAeSchema")

## Fragment narrows the scope to only look at this node and its children
fragment = Nokogiri::XML.fragment(schema)
one_line = "".strip
fragment.xpath('.//*[@name]').each do |field|
  one_line << field.attr('name').strip
  one_line << ",".strip
end
one_line << "\r\n" # going to slurp into Excel so adding Windoze EOL
output.write(one_line)
puts one_line


####
## Get all the IPAM instance nodes and process them into a CSV line each
####
instances = @doc.xpath("//MiqAeClass//MiqAeInstance")
instances.each do |instance|
  fragment = Nokogiri::XML.fragment(instance)
  #puts fragment.inner_text
  one_line = "".strip

  #puts fragment.xpath('.//MiqAeField').size
  fragment.xpath('.//MiqAeField').each do |field|
    if field.attr('name') == 'date_acquired' || field.attr('name') == 'date_released'
      one_line << field.inner_text.delete('^a-zA-Z0-9: ').strip ## strip out the commas b/c they foul up the csv import!!!
    else
      one_line << field.inner_text.strip ## strip off any extra white space
    end

    one_line << ",".strip
  end
  one_line << "\r\n" # going to slurp into Excel so adding Windoze EOL
  output.write(one_line)
  puts one_line
  #puts instance
  #puts " * * * NEXT Instance * * *\n\n"
end


####
## Close the output file
####
output.close unless output == nil
puts " * * * END OF RUBY SCRIPT * * *\n"
