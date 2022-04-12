# ez-ipupdate-nat
Script to update Dynamic DNS with public IP using ez-ipupdate client when behind a NAT firewall.

This is useful when you can't run the ez-ipupdate client on your firewall/router directly, often
because you only control a host inside of that firewall.  In my case, I use this for Oracle Cloud
VM's, which are assigned an internal address and then given a public IP via NAT.

Along with the script, I have included a configuration file designed for ZoneEdit.  It should
be possible to use this with any DNS that is supported by ez-ipudate, but I've only used it
with ZoneEdit.

# General Setup
Please note that these instructions are based on my experience using this on an OCI-provided Ubuntu 20.04 image using systemd.  It assumes certain paths (mainly /etc/ez-ipupdate) and that an ez-ipupd user is created when ez-ipupdate is installed, but without a group.  You very well may need to modify this process for your specific environment.

This assumes that you have sudo access.  If you're running as root, remove the sudo's where they appear.

## Create DNS entries in Dynamic DNS (DDNS)
You will need to create the dynamic records in your DDNS system yourself.

## Install ez-ipupdate on host
You will need to install ez-ipudate on whatever host you're using.  For Linux, that's likely going to be a simple "apt-get instal ez-ipupdate" or "dnf install ez-ipupdate" or such.

If you're asked what type of configuration you want to use, feel free to use something like 'configure later'.  We won't be using any package-supplied configuration, because they all assume that the public IP will be assigned directly to the host, and in this case it won't, so they won't work.

In fact, once the package is installed, you may want to "ls /etc/ez-ipupdate" and make sure there's nothing there; if a configuration file is there, you may want to remove it.  In addition, it would likely also be best to disable the client from running automatically:  we will launch it manually from the script.
```
systemctl stop ez-ipupdate
systemctl disable ez-ipupdate
```

## Get ez-ipupdate-nat code
Let's download the ez-ipupdate code:
```
mkdir ez-ipupdate-nat
wget https://github.com/fts-tmassey/ez-ipupdate-nat/archive/refs/heads/main.zip
unzip main.zip
cd ez-ipupdate-nat
```

## Put ez-ipupdate-nat.sh script and configuration in place
Put ez-ipupdate-nat.sh in place and set permissions.  Something like this:
```
sudo mv ez-ipupdate-nat.sh /etc/ez-ipupdate/
sudo chown root:root /etc/ez-ipupdate/ez-ipupdate-nat.sh
sudo chmod 755 /etc/ez-ipupdate/ez-ipupdate-nat.sh
```
Put configuration info in place, set permisisons and update with proper data.  Something like:
```
sudo groupadd ez-ipupd
sudo usermod -g ez-ipupd ez-ipupd
sudo chmod 640 /etc/ez-ipupdate/hostname.ez-ipupdate.conf
sudo chown root:ez-ipupd /etc/ez-ipupdate/hostname.ez-ipupdate.conf
sudo nano /etc/ez-ipupdate/hostname.ez-ipupdate.conf
```
Find %ZE_USER% and replace with your ZoneEdit username.  Find %ZE_PW% and replace with your ZoneEdit password.  Find %FQDN% and replace with the FQDN of the DYN record you created.

Not using ZoneEdit?  You will need to make more extensive changes to update the configuration for your Dynamic DNS host.  You may want to look for a sample configuration for your provider and compare the two to see the proper changes.

## Manually test script
NOTE:  Manually running as root will create a temproray file owned by that user, which will *not* be able to be overwritten by the service.  We will use a different cache filename to not create a conflict; but make sure you clean up the cache file when you're done.
```
sudo /etc/ez-ipupdate/ez-ipupdate-nat.sh -v -c /etc/ez-ipupdate/hostname.ez-ipupdate.conf -t /tmp/hostname.ez-ipupdate.cachex
```
Now let's clean up the temp file:
```
sudo rm /tmp/hostname.ez-ipupdate.cachex
```
## Create systemd service
We will use systemd to run the script for us.  We will create a one-shot service:  this will only run when manully asked to.  We will then use a timer to schedule this to run periodically.

First, let's put the service files in place:
```
sudo cp ez-ipupdate-nat.service /etc/systemd/system
sudo cp ez-ipupdate-nat.timer /etc/systemd/system
sudo chmod 644 /etc/systemd/system/ez-ipupdate-nat.service
sudo chmod 644 /etc/systemd/system/ez-ipupdate-nat.timer
sudo chown root:root ez-ipupdate-nat.service
sudo chown root:root ez-ipupdate-nat.timer
```
Now we have to tell systemd about the new service, and then we can start and enable it:
```
sudo systemctl daemon-reload
sudo systemctl start ez-ipupdate-nat.timer
sudo systemctl enable ez-ipupdate-nat.timer
```

## Check to see that it's running
Check that the timer is started:
```
journalctl -e -u ez-ipupdate-nat.timer
```
You will see a message that the service is started to restart periodically, and there will be no further logging here.  Let's now make sure that the actual service is indeed being triggered periodically:
```
journalctl -e -u ez-ipupdate-nat.service
```
Once the service is triggered, you will see three lines:  Starting ez-ipupdate-nat, ez-ipupdate-nat.service: Succeeded, and Finished ez-ipupdate-nat.  At that point, your IP is up to date!

# Script Parameters
The script will accept the following parameters:
```
  -c <config file> : Path to ez-ipupdate config file
  -t <cache file>  : Path to IP cache file
                      Default:  /tmp/hostname.ez-ipupdate-nat.cache
  -h               : Show this help information
  -v               : Show verbose information
```
