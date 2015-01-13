# 
# Program: listAmazonEMS.rb
# Description: For a Dynamic Dropdown, list available Amazon EMS managed by this
#              instance
# Author: Dave Costakos <david.costakos@redhat.com>
# License: GPL v3
#-------------------------------------------------------------------------------
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <http://www.gnu.org/licenses/>.
# -------------------------------------------------------------------------------
#
begin

  def log(level, msg)
    $evm.log(level, msg)
  end

  def log_err(err)
    log(:error, "#{err.class} #{err}")
    log(:error, "#{err.backtrace.join("\n")}")
  end

  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end

  log(:info, "Begin Automate Method")

  dump_root

  amazon_hash = {}


  $evm.vmdb(:ems_amazon).all.each { |ems_amazon|
    amazon_hash["#{ems_amazon.provider_region}"] = "#{ems_amazon.id}"
    log(:info, "EMS Amazon: #{ems_amazon.inspect}")
  }

  amazon_hash[nil] = nil
  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = amazon_hash

  log(:info, "Dropdown Values; #{amazon_hash.inspect}")
  
  log(:info, "End Automate Method")

rescue => err
  log_err(err)
  dbtype_hash = {}
  dbtype_hash["#{err.class}: #{err}"] = "#{err.class}: #{err}"
  $evm.object["sort_by"] = "description"
  $evm.object["sort_order"] = "ascending"
  $evm.object["data_type"] = "string"
  $evm.object["required"] = "true"
  $evm.object['values'] = dbtype_hash
  log(:error, "ERROR: Dynamic drop down values: #{$evm.object['values']}")
end