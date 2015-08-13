###################################
#
# EVM Automate Method: release_ip_address_router
#
# Notes: EVM Automate method to release IP Address information from EVM Automate Model.  We are in a hybrid IPAM
#        environment with some BUs not using an IPAM, some using CloudForms internal IPAM, some using BlueCat v3.7x and
#        some using BlueCat v4.x Proteus.  This method is used to route a manual or automated retirement to the correct
#        IPAM method to release the IP.
#
###################################

###################################
# Method for logging
###################################
def log(level, message)
  @method = 'release_ip_address_router'
  @debug = true
  $evm.log(level, "#{@method} - #{message}") if @debug
end


begin
  log(:info, "===== EVM Automate Method: <#{@method}> Started ")

  ## Get Provisioning Object: This will be nil if manually provisioned outside of CloudForms
  prov = $evm.root["miq_provision"]
  $evm.log("info","#{@method}  Inspect prov object: <#{prov.inspect}>") if @debug

  ## Get current VM object
  vm = $evm.root['vm']
  raise "#{@method} VM or Provision Object not found and cannot release IP" if vm.nil? && prov.nil?

  # # # #
  #  Check to see if the VM has been tagged with 'ipam_source' and if so, route it to the proper Proteus network to
  #  release the IP.   If ipam_source tag is not found, check to see if ipam_path tag is present.  If so, release the IP
  #  from CloudForm's internal IPAM system.  If ipam_source and ipam_path tags are not found then it means the the IP
  #  was DHCP or manually set.  We'll forward to the internal CloudForms release method and it will exit properly
  # # # #
  if !prov.nil? || !prov.blank?
    vm_tags = prov.get_tags
    ipam_source = vm_tags[:ipam_source]
  else
    vm_tags = vm.tags
    vm.tags.sort.each { |tag_element| tag_text = tag_element.split('/');
    if tag_text.first == "ipam_source"
      ipam_source = tag_text.last.to_s
      log("info", " VM:<#{vm.name}> Category:<#{tag_text.first.inspect}> Tag:<#{tag_text.last.inspect}>")
    end
    }
    log(:info, " --CAI--  vm.tags(:ipam_source) = #{ipam_source}")
  end

  log(:info," VM Tags: #{vm_tags.inspect}")
  ipam_msg = ipam_source.nil? ? "* * BlueCat IPAM not used" : "BlueCat IPAM DB Name:  #{ipam_source}"
  log(:info," #{ipam_msg}")

   ## if ipam_source contains something and matches the IPAM manager source text, we'll redirect to the proper IPAM system
    if /ip_mgr/i =~ ipam_source   # regex to find the source that starts with IP_MGR (IE: IP_Mgr_Lab_v4_0)
      # redirect to bluecat release
      log(:info, "- - Release the Reserved IP from BlueCat Proteus IPAM: /Customer/Integration/MIQ_IPAM/BlueCat/#{ipam_source}#release")
      $evm.instantiate("/Customer/Integration/BlueCat_IPAM/BlueCat/#{ipam_source}#release")
      sleep(30.seconds)
    else
      #redirect to internal CF IPAM release method
      log(:info, "- - Release the Reserved IP from MIQ internal IPAM")
      $evm.instantiate("/Customer/Integration/MIQ_IPAM/IPAM_Methods/miq_release_ip_address")
      sleep(30.seconds)
    end
  #
  # Exit method
  #
  log(:info, "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

    #
    # Set Ruby rescue behavior
    #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
###################################
# End of EVM Automate Method: release_ip_address_router
###################################
