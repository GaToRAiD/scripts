#!/bin/bash
#Author: Andrew Barrett
#Purpose: Restart systems that have been on for more than 5 days.
#Date: 05/20/2015

#Setup File for Progress Bar
rm -f /tmp/hpipe
mkfifo /tmp/hpipe
sleep 0.2

#Declare Variables
cocoaPath="/Applications/CocoaDialog.app/Contents/MacOS/CocoaDialog"
deferNumber=`cat /tmp/defer`
DAYS="days,"
DAYScheck=$(uptime | awk {'print $4'})

#Function to get uptime of computer in days only.
function UptimeCheck ()
{
    result=$(uptime | awk {'print $3'} | sed 's/,/ /g' | sed 's/d/ d/g')
    if [[ $result -ge 5 ]]; then
    	#Calls Restart function if the machine uptime is 5 days or more.
    	restartProtocol $result
    else
    	if [ -a "$defNumber" ]; then
    		#Removes the defer file if it exists if machine is not up longer than 4 days. Not really needed since tmp dir gets cleared on restart.
    		rm -f /tmp/defer
    	fi
    fi
    
}

#Function to restart the machine
function restartProtocol(){

#Checks to see if the deter file exists, if not set the variable to 0.
if [ -z "$deferNumber" ]; then
	deferNumber=0
fi

#Checks to see if deferrals are maxed out.
if [[ "$deferNumber" == 2 ]]; then
	/Applications/CocoaDialog.app/Contents/MacOS/CocoaDialog progressbar --title "System Restart" --text "You have reached your max deferrals for postponing restart." --icon-file "/System/Library/CoreServices/loginwindow.app/Contents/Resources/Restart.png" --icon-height 48 --icon-width 48 --width 450 --height 90 --nocancel < /tmp/hpipe &
	
	#Setting up progress bar.
	exec 3<> /tmp/hpipe
	echo "100" >&3
	sleep 1.5
	#Progress amount and time about 300 secs = 5 mins.
	progLeft="100"
	secsLeft="300"
	
	#Create the progress bar and timer in dialog box.
	while [[ "$progLeft" -gt 0 ]]; do
		sleep 3
		let progLeft=( $progLeft-1 )
		let secsLeft=( $secsLeft-3 )
		echo "$progLeft $secsLeft seconds until your Mac reboots.  Please save any work now.  Feel free to restart your computer or it will be restarted after countdown concludes." >&3
	done
	#Remove defer file before rebooting machine.
	rm -f /tmp/defer
	reboot
fi

#Checks to see if you still have deferrals left.
if [[ "$deferNumber" -lt 2 ]]; then
		promptAnswer=`"$cocoaPath" yesno-msgbox --title "System Restart" --text "Restart required" --informative-text "Your machine has been on for $1 days, would you like to restart?" --no-cancel --timeout 90 --float`
		#Checks to see if you said no or didn't answer it at all, then adds 1 to deferral.
		if [ "$promptAnswer" == 2 -o "$promptAnswer" == 0 ]; then
			let "deferNumber+=1"
			echo $deferNumber > /tmp/defer
		fi
		#Restarts the machine on yes answer.
		if [ "$promptAnswer" == 1 ]; then
			rm -f /tmp/defer
			reboot
		fi
fi
}
#Checks to see if you have Cocoadialog prior to running, if you don't then it will get it from JSS.
if [ -z "$cocoaPath" ];
	jamf policy -id 1936	
fi
#Checks to see if the variable is equal to days not day.
if [ $DAYScheck = "$DAYS" ]; then
UptimeCheck
fi


