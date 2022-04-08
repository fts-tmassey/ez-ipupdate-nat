# ez-ipupdate-nat
Script to update Dynamic DNS with public IP using ez-ipupdate client when behind a NAT firewall.

This is useful when you can't run the ez-ipupdate client on your firewall/router directly, often
because you only control a host inside of that firewall.  In my case, I use this for Oracle Cloud
VM's, which are assigned an internal address and then given a public IP via NAT.

Along with the script, I have included a configuration file designed for ZoneEdit.  It should
be possible to use this with any DNS that is supported by ez-ipudate, but I've only used it
with ZoneEdit.

# General Setup

## Create DNS entries in Dynamic DNS (DDNS)
You will need to create the dynamic records in your DDNS system yourself.

## Install ez-ipupdate on host
You will need to install ez-ipudate on whatever host you're using.  For Linux, that's likely going to be a simple "apt-get instal ez-ipupdate" or "dnf install ez-ipupdate" or such.

If you're asked what type of configuration you want to use, feel free to use something like 'install later'.  We won't be using any package-supplied configuration, because they all assume that the public IP will be assigned directly to the host, and in this case it won't, so they won't work.

In fact, once the package is installed, you may want to "ls /etc/ez-ipupdate" and make sure there's nothing there; if a configuration file is there, you may want to remove it.  In addition, it would likely also be best to disable the client from running automatically:  we will launch it manually from the script.
```
systemctl stop ez-ipupdate
systemctl disable ez-ipupdate
```

## Put ez-ipupdate-nat.sh script and configuration in place
Copy ez-ipupdate-nat.sh to /etc/ez-ipupdate/ez-ipupdate-nat.sh and set permissions.  Something like this:
```
cp ez-ipupdate-nat.sh /etc/ez-ipupdate/
chown root:root /etc/ez-ipupdate/ez-ipupdate-nat.sh
chmod 755 /etc/ez-ipupdate/ez-ipupdate-nat.sh
```
Copy configuration script to /etc/ez-ipupdate, set permisisons and update with proper data.  Something like:
```
groupadd ez-ipupd
usermod -g ez-ipupd ez-ipupd
chmod 640 /etc/ez-ipupdate/hostname.ez-ipupdate.conf
chown root:ez-ipupd /etc/ez-ipupdate/hostname.ez-ipupdate.conf
nano /etc/ez-ipupdate/hostname.ez-ipupdate.conf
```
Find %ZE_USER% and replace with your ZoneEdit username.  Find %ZE_PW% and replace with your ZoneEdit password.  Find %FQDN% and replace with the FQDN of the DYN record you created.

## Manually test script
NOTE:  Manually running as root will create a temproray file owned by root, which will *not* be able to be overwritten by the service.  We will use a different cache filename to not create a conflict; but make sure you clean up the cache file when you're done.
`/etc/ez-ipupdate/ez-ipupdate-nat.sh -v -c /etc/ez-ipupdate/hostname.ez-ipupdate.conf -t /tmp/hostname.ez-ipupdate.cachex`
Now let's clean up the temp file:
`rm /tmp/hostname.ez-ipupdate.cachex`
## Create systemd service
We will use systemd to run the script for us.  We will create a one-shot service:  this will only run when manully asked to.  We will then use a timer to schedule this to run periodically.
```
cp ez-ipupdate-nat.service /etc/systemd/system
cp ez-ipupdate-nat.timer /etc/systemd/system
systemctl start ez-ipupdate-nat.timer
systemctl enable ez-ipupdate-nat.timer
```

## Check to see that it's running
Check that the timer is starting periodically as it should:
`journalctl -e -u ez-ipupdate-nat.timer`
Check that the service is working once the timer has triggered it:
`journalctl -e -u ez-ipupdate-nat.service`
