#
# This method assign a Floating IP to OpenStack VMs working with Nuage Networks.
# Is a service post-provisioning method and asks for a Floating IP to each service vm.
# Uses the first Enterprise and Domain accessible to the user.
# Try to use unassigned Floating IPs from recived pool, if there is none, request a one.
# Assign the Floating IP to the first VM vPort without Floating IPs.
#
# Authors: Manel - david.mendes@ext.produban.com
#

begin

  require 'net/https'
  require 'base64'
  require 'json'

  @method = '/Automation/NuageIntegration/NuageIntegration'
  $evm.log("info", "#{@method} Started")

  # Generic HTTP Get for Nuage API.
  def genericGet(request)
    uri = URI(['https://', @server, '/', @path, '/', request].join)

    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      if @APIKey.nil?
        base64authentication = 'fake'
      else
        base64authentication = Base64.strict_encode64(@username+":"+@APIKey)
      end
      headers = {'X-Nuage-Organization' => @organization, 'Content-Type' => 'application/json', 'Authorization' => 'Basic ' + base64authentication}
      request = Net::HTTP::Get.new(uri.request_uri, headers)
      if @APIKey.nil?
        request.basic_auth(@username, @password)
      end
      response = http.request(request)
       return response.body
    end
  end

  # Generic HTTP Get for Nuage API with readable output.
  def prettyGenericGet(request)
   JSON.parse(genericGet(request)).each do |object|
      $evm.log("info", "#{@method} - #{JSON.pretty_generate(object)}")
    end
  end

  # Generic HTTP Post for Nuage API.
  def genericPost(request, body)
    uri = URI('https://'+@server+'/'+@path+'/'+request)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      base64authentication = Base64.strict_encode64(@username+":"+@APIKey)
      headers = {'X-Nuage-Organization' => @organization, 'Content-Type' => 'application/json', 'Authorization' => 'Basic ' + base64authentication}
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = body
      if @APIKey.nil?
        request.basic_auth(@username, @password)
      end
      response = http.request(request)
      return response.body
    end
  end

  # Generic HTTP Put for Nuage API.
  def genericPut(request, body)
    uri = URI('https://'+@server+'/'+@path+'/'+request)

    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
      base64authentication = Base64.strict_encode64(@username+":"+@APIKey)
      headers = {'X-Nuage-Organization' => @organization, 'Content-Type' => 'application/json', 'Authorization' => 'Basic ' + base64authentication}
      request = Net::HTTP::Put.new(uri.request_uri, headers)
      request.body = body
      if @APIKey.nil?
        request.basic_auth(@username, @password)
      end
      response = http.request(request)

      return response.body
    end
  end

  # Find a free vPort on a VM.
  def getVMFirstVPort(openStackUUID)
    $evm.log("info", "#{@method} - Finding first available vPort to assign a Floating IP on VM #{openStackUUID}...")
    vms = genericGet('enterprises/'+@enterpriseID+'/vms')
    JSON.parse(vms).each do |vm|
      if vm['UUID'] == openStackUUID
        vm['interfaces'].each do |interface|
          if interface['VMUUID'] == openStackUUID and interface['associatedFloatingIPAddress'] == nil
            $evm.log("info", "#{@method} - Found vPort #{interface['VPortID']}\n\n")
            return interface['VPortID']
         end
        end
      end
    end
    $evm.log("error", "#{@method} - Couldn't get a valid vPort to associate Floating IPs on VM #{openStackUUID}")
    exit MIQ_ABORT
  end

  # Use the pool <floatingIPSubnet> to reserve a Floating IP.
  def reserveFloatingIP()
    body = { 'associatedSharedNetworkResourceID' => "#{@floatingIPSubnet}" }

    result = JSON.parse(genericPost('domains/' + @domainID + '/floatingips', body.to_json))

    if result[0].nil?
      $evm.log("error", "#{@method} - Can't reserve a new FloatingIP - #{result}")
      exit MIQ_ABORT
    end

    return result[0]['ID']
  end

  # Try to get any unassigned Floating IP from recived pool, if there is none, reserve a new one.
  def getFloatingIP()
    $evm.log("info", "#{@method} - Finding a not assigned floating IP on domain #{@domainID}...")
    floatingips = genericGet('domains/'+@domainID+'/floatingips')
    if floatingips != ''
       JSON.parse(floatingips).each do |floating|
        if floating['assigned'] == false and floating['associatedSharedNetworkResourceID'] == @floatingIPSubnet
          $evm.log("info", "#{@method} - Found floating IP: #{floating['ID']}\n\n")
          return floating['ID']
        end
      end
    end
    $evm.log("info", "#{@method} - There is no free floating IP. Reserving a new one...")

    floatingIP = reserveFloatingIP()

    $evm.log("info", "#{@method} - Reserved floating IP: #{floatingIP}")
    return floatingIP
  end

  # Assign a Floating IP to a vPort of some VM
  def assignFloatingIPToVM(vPortID, floatingIPID)
    body = { 'associatedFloatingIPID' => "#{floatingIPID}" }

    result = genericPut('vports/'+vPortID, body.to_json)

    $evm.log("info", "#{@method} - FloatingIP #{floatingIPID} was associated to vPort #{vPortID}:")
    prettyGenericGet('vports/'+vPortID)
  end

  ######## main ########

  # check dialog_floatingip variable to decide whether or not request floatingips to service vms
  req = $evm.root['service_template_provision_task']
  miqRequest = $evm.vmdb('miq_request').find_by_id(req.miq_request_id)
  if miqRequest.options[:dialog]['dialog_floatingip'] == "t"

    @server           ||= $evm.object['server']
    @path               = 'nuage/api/v3_0'
    @username         ||= $evm.object['username']
    @password         ||= $evm.object['password']
    @organization     ||= $evm.object['organization']
    @floatingIPSubnet ||= $evm.object['floatingIPSubnet']
    @APIKey             = nil
    @enterpriseID       = nil
    @domainID           = nil

    # Generate an API Key (token).
    @APIKey = JSON.parse(genericGet('me'))[0]['APIKey']

    # Get the Nuage enterprise to use.
    @enterpriseID = JSON(genericGet('enterprises'))[0]['ID']

    # Get the Nuage domain to use,
    @domainID = JSON.parse(genericGet('enterprises/'+@enterpriseID+'/domains'))[0]['ID']

    # Get all the provisioned VMs of service
    provisioned_vms = req.destination.vms

    # Assign a Floating IP for each VM
    provisioned_vms.each do |vm|

      currentVM = vm.uid_ems

      # Get a Floating IP to assign to the current VM (WARNING: using any accesible Floating IP pool)
      floatingIPID = getFloatingIP()

      # Get a vPort from the current VM (WARNING: using any vPort without FloatingIP, not a specific one)
      vPortID = getVMFirstVPort(currentVM)

      # Assign the reserved Floating IP to the current VM
      assignFloatingIPToVM(vPortID, floatingIPID)

    end

  else

    # Dialog variable <floatingip> wasn't checked, don't create Floating IPs to the service VMs.
    $evm.log("info", "#{@method} - Nothing done.")

  end

  $evm.log("info", "#{@method} Ended")

rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
