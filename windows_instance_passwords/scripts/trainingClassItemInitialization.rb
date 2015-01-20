# 
# Program: trainingClassItemInitialization.rb
# Description: Initialize the Training Class Demo
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

  @task = nil
  @service = nil

  # Simple logging method
  def log(level, msg)
    $evm.log(level, msg)
  end

  # Error logging convenience
  def log_err(err)
    log(:error, "#{err.class} #{err}")
    log(:error, "#{err.backtrace.join("\n")}")
  end

  # standard dump of $evm.root
  def dump_root()
    log(:info, "Root:<$evm.root> Begin $evm.root.attributes")
    $evm.root.attributes.sort.each { |k, v| log(:info, "Root:<$evm.root> Attribute - #{k}: #{v}")}
    log(:info, "Root:<$evm.root> End $evm.root.attributes")
    log(:info, "")
  end


  log(:info, "Begin Automate Method")

  dump_root

  # Get the task object from root
  @task = $evm.root['service_template_provision_task']
  if @task
    # List Service Task Attributes
    @task.attributes.sort.each { |k, v| log(:info, "#{@method} - Task:<#{@task}> Attributes - #{k}: #{v}")}

    # Get destination service object
    @service = @task.destination
    log(:info,"Detected Service:<#{@service.name}> Id:<#{@service.id}>")
  end


  #@task.set_option(:remove_from_vmdb_on_fail, false)


  dialog_options = @task.dialog_options
  log(:info, "Dialog Options: #{dialog_options.inspect}")

  dialog_options.each { |key, value|
    log(:info, "Dialog Key: #{key} => #{value}")
    dialog_regex = /dialog_/
    next unless dialog_regex =~ key
    # key is frozen, so make a copy and operate on it
    newkey = "#{key}"
    newkey.sub! 'dialog_', ''
    log(:info, "Setting Task Option to :#{newkey} => #{value}")
    password_regex = /^password::/
    unless password_regex =~ key
      @task.set_option(:"#{newkey}", value)
    else
      require '/var/www/miq/lib/util/miq-password.rb'
      MiqPassword.key_root = "/var/www/miq/vmdb/certs"
      newvalue = MiqPassword.decrypt(value)
      newkey.sub! 'password::', ''
      log(:info, "Found Encrypted Value, decrypting and setting: #{newkey} => #{newvalue}")
      @task.set_option(:"#{newkey}", "#{newvalue}")
    end
  }

  @service.name = "Training Class: #{@task.get_option(:class_name)}"


  log(:info, "Exit Automate Method")

rescue => err
  log_err(err)
  $evm.root['ae_result'] = "error"
  @task.message = "Error Provisioning AWS Security: #{err.class} '#{err}'"
  @service.remove_from_vmdb if @service && @task && @task.get_option(:remove_from_vmdb_on_fail)
  exit MIQ_ABORT
end