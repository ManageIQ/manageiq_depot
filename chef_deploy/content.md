One of the largest challenges facing new users of ManageIQ is how to get started. For a few months, users have been able to download new images, but those are rather large. What this Chef cookbook allows you to do is build ManageIQ from source and then quickly deploy. This work was released by Booz Allen Hamilton as part of its [Jellyfish Cloud Broker project](http://booz-allen-hamilton.github.io/projectjellyfish/).

Requirements
------------

### Platforms

Tested on RHEL 6.5 and CentOS 6.5. Should work on any Red Hat family distributions.

### Cookbooks

- git
- yum
- yum-epel
- iptables
- postgresql
- database
- xml
- ntp
- memcached

Attributes
----------

###### Attributes specifically for ManageIQ

- `default["manageiq"]["db_username"]` - Username for the ManageIQ database user (default: "evm")
- `default['manageiq']['db_password']` - password for the ManageIQ database user
- `default['manageiq']['code_repo']` - GIT Repo URL used to build the server

###### Attributes for the RVM cookbook

- `default['rvm']['user_installs']` - Username for the user who is building and running the ManageIQ processes

###### Attributes for the PostgreSQL Database

- `default['postgresql']['password']['postgres']` - Set the root password for the database (default: sets to the manageiq/db_password)
- `default["postgresql"]["pg_hba"]` - Configures the pg_hba file to allow incoming connections
- `default["postgresql"]["config"]["port"]` - Database Port (default: 5432)
- `default["postgresql"]["host"]` - Host Information (default: 127.0.0.1)
- `default['postgresql']['config']['listen_addresses']` - Listen Addresses for the database (default: "*")

Usage
-----
Simply add the cookbook to your runlist or add the cookbook to a role you have created.


Deploying a ManageIQ Server
-----------
This section details "quick deployment" steps.

1. Install Chef Client


          $ curl -L https://www.opscode.com/chef/install.sh | sudo bash

2. Create a Chef repo folder and a cookbooks folder under the /tmp directory


          $ mkdir -p /tmp/chef/cookbooks
          $ cd /tmp/chef/

3. Create a solo.rb file


          $ vi /tmp/chef/solo.rb
         
               file_cache_path "/tmp/chef/"
               cookbook_path "/tmp/chef/cookbooks"

4. Create a manageiq.json file, this will be the attributes file and contains the run_list


          $ vi /tmp/chef/manageiq.json
        
                {
                  "run_list": [
                  "recipe[chef-manageiq]"
                 ]
                }


4. Install dependencies:

        $ cd /tmp/chef/cookbooks
        
        $ knife cookbook site download postgresql
        $ tar xvfz postgresql-*.tar.gz
        $ rm -f postgresql-*.tar.gz
         
        $ knife cookbook site download iptables
        $ tar xvfz iptables-*.tar.gz
        $ rm -f iptables-*.tar.gz
         
        $ knife cookbook site download database
        $ tar xvfz database-*.tar.gz
        $ rm -f database-*.tar.gz
         
        $ knife cookbook site download rvm
        $ tar xvfz rvm-*.tar.gz
        $ rm -f rvm-*.tar.gz
         
        $ knife cookbook site download xml
        $ tar xvfz xml-*.tar.gz
        $ rm -f xml-*.tar.gz
         
        $ knife cookbook site download git
        $ tar xvfz git-*.tar.gz
        $ rm -f git-*.tar.gz
         
        $ knife cookbook site download ntp
        $ tar xvfz ntp-*.tar.gz
        $ rm -f ntp-*.tar.gz
         
        $ knife cookbook site download memcached
        $ tar xvfz memcached-*.tar.gz
        $ rm -f memcached-*.tar.gz
         
        $ knife cookbook site download yum
        $ tar xvfz yum-*.tar.gz
        $ rm -f yum-*.tar.gz
             
        $ knife cookbook site download yum-epel
        $ tar xvfz yum-epel-*.tar.gz
        $ rm -f yum-epel-*.tar.gz
         
        $ knife cookbook site download openssl
        $ tar xvfz openssl-*.tar.gz
        $ rm -f openssl-*.tar.gz
         
        $ knife cookbook site download chef-sugar
        $ tar xvfz chef-sugar-*.tar.gz
        $ rm -f chef-sugar-*.tar.gz
         
        $ knife cookbook site download build-essential
        $ tar xvfz build-essential-*.tar.gz
        $ rm -f build-essential-*.tar.gz
        
        $ knife cookbook site download apt
        $ tar xvfz apt-*.tar.gz
        $ rm -f apt-*.tar.gz

        $ knife cookbook site download aws
        $ tar xvfz aws-*.tar.gz
        $ rm -f aws-*.tar.gz

        $ knife cookbook site download mysql
        $ tar xvfz mysql-*.tar.gz
        $ rm -f mysql-*.tar.gz
        
        $ knife cookbook site download yum-mysql-community
        $ tar xvfz yum-mysql-community-*.tar.gz
        $ rm -f yum-mysql-community-*.tar.gz

        $ knife cookbook site download mysql-chef_gem
        $ tar xvfz mysql-chef_gem-*.tar.gz
        $ rm -f mysql-chef_gem-*.tar.gz

        $ knife cookbook site download xfs
        $ tar xvfz xfs-*.tar.gz
        $ rm -f xfs-*.tar.gz

        $ knife cookbook site download dmg
        $ tar xvfz dmg-*.tar.gz
        $ rm -f dmg-*.tar.gz

        $ knife cookbook site download runit
        $ tar xvfz runit-*.tar.gz
        $ rm -f runit-*.tar.gz
        
        $ knife cookbook site download windows
        $ tar xvfz windows-*.tar.gz
        $ rm -f windows-*.tar.gz     
        
        $ knife cookbook site download chef_handler
        $ tar xvfz chef_handler-*.tar.gz
        $ rm -f chef_handler-*.tar.gz        
        
        $ knife cookbook site download chef_gem
        $ tar xvfz chef_gem-*.tar.gz
        $ rm -f chef_gem-*.tar.gz    
        
6. Download and extract the cookbook:

          $ yum install -y wget
          $ wget https://github.com/booz-allen-hamilton/chef-manageiq/archive/master.tar.gz
          $ tar xvfz master.tar.gz 
          $ rm -rf master.tar.gz 
          $ mv chef-manageiq-master/ chef-manageiq
    
7. Run Chef-solo:

          $ cd /tmp/chef
          $ chef-solo -c solo.rb -j manageiq.json


License & Authors
-----------------

- Author:: Chris Kacerguis
- Author:: Mandeep Bal


```text

Copyright:: 2014, Booz Allen Hamilton

For more information on the license, please refer to the LICENSE.txt file in the repo

```


