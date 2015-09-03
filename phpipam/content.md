When people search for an open source IP Address Management (IPAM) solution, they often end with PHPIPAM. This module will provide users with the automate classes/instances/methods to integrate ManageIQ with PHPIPAM 1.1.010. The version is important as PHPIPAM is now  [hosted on github](http://github.com/phpipam/phpipam), but has not officialy released an newer version.

### Patching PHPIPAM 

First of all, the API of PHPIPAM lacks the following features :
 - Get subnet information from its description (kind of name)
 - Reserve the next available IP address in a subnet
 - Release an IP address
As these features are critical to ManageIQ, I wrote a patch (attached to this page) that covers the missing features.

To apply the patch, simply go to where you store phpipam. In my instance, it is in /var/www/html:

```bash
# cd /var/www/html
# patch -p0 < /root/phpipam-1.1.010-cfme.patch
```

### Install ruby-mcrypt gem

ManageIQ requires an additional gem to be able to talk to PHPIPAM : ruby-mcrypt. When sending a request, the body has to be encrypted using an Mcrypt primitive. It is done quite easily (if you have an internet access) :

```bash
# yum install ruby200-ruby-devel
# yum install http://dl.fedoraproject.org/pub/epel/6/x86_64/libmcrypt-2.5.8-9.el6.x86_64.rpm http://dl.fedoraproject.org/pub/epel/6/x86_64/libmcrypt-devel-2.5.8-9.el6.x86_64.rpm
# yum install gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers mpfr ppl

# gem install ruby-mcrypt

# yum -y remove libmcrypt-devel ruby200-ruby-devel gcc cloog-ppl cpp glibc-devel glibc-headers kernel-headers mpfr ppl
```

### Configure API in PHPIPAM

In PHPIPAM, you need to enable the API. In the "Administration" menu click on "IPAM settings". Then in the section called "Feature settings", check the box call "API". Finally, click on "Save changes". The API is enabled and a new entry appeared in menu on the left.

You now have to create an application that will be given an id and a token to authenticate to the API. Click on the "API management" entry of the menu on the left. Click on the button "Create an API key". This will generate a token and ask you :
 - App id: manageiq
 - App permissions: Read/Write (do not select Read/Write/Admin, as it does not allow you to do some operations)
 - App description: ManageIQ
Click on "Add" and get back to CloudForms.

### Import domains in ManageIQ Automate

You are now ready to interface CloudForms with ManageIQ. I have written integration code and propose it in two repositories :

- Configuration - Class that defines the PHPIPAM configuration item : server, application context, api\_key and api\_token. I also provide a "Default" instance, that you need to modify with your information.
- Custom - Utility class whose instances do all the magic. There are two instances : AcquireIPAddress and ReleaseIPAddress, that will just fit in your VMProvision state machine.

Hope you will find it useful.
