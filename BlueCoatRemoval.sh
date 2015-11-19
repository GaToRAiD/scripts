#!/bin/bash

#Variables
agentLocation="/Library/Application Support/bcua"
kextLocation="/Library/Extensions/bcua.kext"
launchAgent="/Library/LaunchAgents/com.bluecoat.ua.notifier.plist"
launchDaemon="/Library/LaunchDaemons/com.bluecoat.ua.plist"
bcService="/opt/.bluecoat-ua/"


#unload daemons
/bin/launchctl unload $launchAgent
echo "$launchAgent has been unloaded"
/bin/launchctl unload $launchDaemon
echo "$launchDaemon has been unloaded"

#unload kext file
/sbin/kextunload $kextLocation
echo "Kext has been unloaded"

#check if service is still running
serviceStatus=`/bin/ps aux | grep bluecoat | grep -v grep | awk '{print $2}'`

if [ -z "$serviceStatus" ]; then
	echo "Process has been terminated"
else
	/bin/kill -9 $serviceStatus
fi

#remove files
/bin/rm -rf $agentLocation
/bin/rm -f $kextLocation
/bin/rm -f $launchAgent
/bin/rm -f $launchDaemon
/bin/rm -rf $bcService

#Exiting with joy
echo "Bluecoat has been removed, you may enjoy surfing the net"
echo "Rebooting the machine now"
