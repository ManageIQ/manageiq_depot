
One of the most amazing, yet rarely discussed, benefits of using ManageIQ is the flexibility end users get through the Automate Model.  If ManageIQ does not support a feature out-of-the-box, the Automate Model is there for you to extend the platform and add basic support for the features you'd like to add to automate.  All you need to extend the platform is a ruby gem (or gems) to support the features you want to add, some ruby scripting skill, and some experience with the automate model.

This post in the ManageIQ depot is meant to be a case study of sorts designed to share some experience on how to get started with ManageIQ.  I'll describe how to extend the automate model to deploy Amazon EC2 Windows AMIs and using AWS and set randomized Windows Administrator passwords using the EC2 "GetPasswordData" API call.  Finally, I share a full ManageIQ state machine to accomplish an example of a specific case study that uses this GetPasswordData API call.

Reference: http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_GetPasswordData.html

Background
----------
Windows AMIs in Amazon support the generation of randomized Administrator passwords and the retrieval and decryption of those passwords via API.  If the AMI enables the EC2Config service plugin and the Ec2SetPassword attribute is enabled, a randomized password is set that can be decrypted with the private key portion of an Amazon EC2 KeyPair object.  For those bundling up their own AMIs, you must set the Ec2SetPassword attribute when you bundle your AMI.  But if you use a public AMI, this should already be set for you.


#### AWS Reference Docs:
- http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_GetPasswordData.html
- AWS::EC2 Ruby Object: http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2.html
- AWS::EC2::Client Ruby Object: http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/Client.html
- AWS::EC2::KeyPair Ruby Object: http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/EC2/KeyPair.html


Automate Extension Overview
---------------------------
The passwords themselves are available after an instance is deployed via ```get_password_data``` call to an AWS::EC2::Client Object.  This get_password data is not available for some time after an instance is deployed (3-5 minutes in my testing).  Once you get the data, you must be able to decrypt it using the private key portion of an Amazon EC2 KeyPair Object. In this automate extension, you should learn the following important items:

- How to get a Ruby `AWS::EC2` Object in Automate
- How to create an `AWS::EC2::KeyPair` object as part of Automate
- How to save an `AWS::EC2::KeyPair` private key data for later use in automate.
- How to use the Automate concept of Re-Entrancy to wait until PasswordData has been set by AWS on an instance
- How to Send an Email from automate.



#### How to get an AWS::EC2 Object

The Automate Model has the concept of a Management System.  The Management System object has authentication and access credentials that are associated with it an may be retrieved as part of the object.  Management System objects may be obtained from a "VM" object via the `vm.ext_management_system` call, or from $evm.vmdb searches.  Once you have the management system object for an Amazon Cloud Provider in ManageIQ, you can easily extend the automate model by using the pre-installed `aws-sdk` ruby gem to connect to AWS programmatically.  Here is a snippet of example code that retrives the object from the VMDB by region name, and gets an ruby `AWS::EC2` Object.
```
          def get_aws_object(ext_mgt_system, type="EC2")
            require 'aws-sdk'
            AWS.config(
              :access_key_id => ext_mgt_system.authentication_userid,
              :secret_access_key => ext_mgt_system.authentication_password,
              :region => ext_mgt_system.provider_region
            )
            return Object::const_get("AWS").const_get("#{type}").new()
          end
          ...
          provider_region = "us-west-1" # for example
          aws_mgt = $evm.vmdb(:ems_amazon).all.detect { |mgt_system|
            "#{mgt_system.provider_region}" == provider_region
          }
          ec2 = get_aws_object(aws_mgt)
          # Now you have an AWS::EC2 Ruby Object, yea!
```
Again, this is just an example snippet.

PRO TIP: You may notice the get_aws_object method has a type parameter which defaults to EC2.  One could also use this same method to get a connection to the AWS RDS service, or the AWS S3 service.  One could use whichever services are enabled as part of this account which enables users to extend into all parts of the AWS environment, not just virtual machines.
	

#### How to Create an AWS::EC2::KeyPair

Now that you know how to get an `AWS::EC2` Object, you can literally do anything in ManageIQ Automate that is available in EC2 including creating a brand new EC2 KeyPair.  In AWS, if you launch a Windows instances with an AWS KeyPair, you can then use that keypair to decrypt the password for the Administrator user.  So I recommend simply creating throwaway EC2 KeyPairs that are only used to launch a Windows instance and decrypt the password.  They need not be used for anything ever again.

The trick here is to get the KeyPair and save it for later use.  In this example, we'll save the private key pair data in an Automate ServiceTemplateProvisioning Task object.  This implies that this will work within the context of a ManageIQ generic service catalog item deployment.
```
          # First, get a reference to the task object, then the service object
          task = $evm.root['service_template_provisioning_task']
          service = task.destination

          # presuming you already have an EC2 Object, you can now create a new keypair
          keypair = ec2.key_pairs.create("mykeypair")
```
#### How to Save an AWS::EC2::KeyPair private key for later use

Once you've created the `AWS::EC2::KeyPair` object, you can save it in the task object using the `set_option` call.  The private key_pair data must be saved because the private key is only available in teh AWS SDK when the keypair is created.  Later calles to retrive an existing key pair do not retrieve the private key.  It is up to the programmer to save this someplace it can be retrieved safely and securely.
```
          task.set_option(:aws_private_key, "#{keypair.private_key}")
          task.set_option(:aws_keypair, "mykeypair")
```

#### How to Use Re-Entrancy in Automate

Once you have an `AWS::EC2::KeyPair` object and its `private_key` data, all you need to do is provision and instance.  Once the instance provisioning is kicked off, you unfortunately have to wait until the AWS Ec2Config service actually sets and makes available the password data for the new instance you've created.  In my experience, this generally takes between 3 and 5 minutes (at least for the AWS regions in the US.  Luckily, ManageIQ automate is reentrant.  This gives coders the ability to periodically check a service and wait until it completes before gathering data and moving on to the next step in the overall process.  Here is an example snippet which takes a VM object, checks to see if the password data is available, waits if not using Automate retry, and the gets and decrypts the password once it is ready.
```
          # Retry Method
          # basic retry logic
          def retry_method(retry_time="1.minute")
            $evm.log("info", "Retrying in #{retry_time} seconds")
            $evm.root['ae_result']         = 'retry'
            $evm.root['ae_retry_interval'] = retry_time
            exit MIQ_OK
          end
          # Get the VM object from miq_provision
          prov = $evm.root['miq_provision']
          vm = prov.vm
          ec2 = get_aws_object(vm.ext_management_system)
          ec2_instance = ec2.instances["#{vm.ems_ref}"]
          password_response = ec2.client.get_password_data({
            :instance_id => ec2_instance.id
          })
          # if password_data is nil, no password yet, retry
          # which would end execution of this method
          retry_method if password_response.password_data.nil?
          private_key = prov.get_option(:aws_private_key)
          # Create an openssl object to decrypt the data
          ssl_private_key = OpenSSL::PKey::RSA.new(private_key)
          # Get the decrypted password by base64 decoding the password_data
          # using the ssl private key
          decrypted = ssl_private_key.private_decrypt(
                Base64.decode64(password_response.password_data))
```
         
#### How to Send an Email from Automate

Now that you have the password, it might be useful to send an email.  Luckily, there is a function available for you to send email from Automate.
```
          email_body = "Password is #{decrypted}"
          $evm.execute(:send_email, to_email, your_from_email, your_subject, email_body)
```


Case Study
----------

Now that I've given an overview, here is a specific example. (TBD)


