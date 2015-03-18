#!/bin/bash
#
# Title:Casper Active Directory User Group Membership Query
# By: Andrew Barrett
# Version: 1.0.0
# Purpose: Designed to import user groups from Active Directory
#		   into JSS for use of making policies to scope to
#		   groups and not computers.
#
#
#Variables
logFileMaxSize=2048
mysql_client_path='/path/to/my/sql/'
mysql_database='DatabaseName'
mysql_host='JSSHost'
log_location="/var/log/ADUserGroupUpdate.log"
logFileCurrentSize=`du -k $log_location | cut -f 1`

if [ $logFileCurrentSize -ge $logFileMaxSize ]; then
 rm $log_location
fi


# Warning: Using a password on the command line interface is insecure.
# It is much safer to specify these in mysql.cnf than to hard code them into a script. 
mysql_user='reports'
mysql_pass='jamfsw03'

jssUser=JSSAPIUsername
jssPass='passwordForJSS'
jssHost=https://localhost:8443/



#Blank xml packet to retrieve AD Group Membership from JSS.
xmlGetADMembership="<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>
	<computer>
	</computer>"

#Functions:

#Function to Check JSS Groups vs. AD Groups
# $1 = JSSComputerID
# $2 = UserADGroupMembership List

CheckJSSADMembership(){
	
#Properly format array from AD from new line delimited
#to space delimited for processing of items in the array.

#membership=`echo ${2} | sed ':a;N;$!ba;s/\n/ /g'`

#Use blank xml packet to get full xml output from JSS.

theJSSresponse=$( /usr/bin/curl \
--header "Content-Type: text/xml; charset=utf-8" \
--data "${xmlGetADMembership}" \
--request GET \
--connect-timeout 5 \
--max-time 10 \
--user ${jssUser}:${jssPass} \
--insecure \
${jssHost}JSSResource/computers/"id"/$1 2> /dev/null )

#Take full output from JSS and just return the AD Group
#Membership EA.  This is a comma delimited array.

userGroups=$(Echo $theJSSresponse | xpath "//extension_attribute[name/text() = 'AD Group Membership']/value" | sed -n 's|<value>\(.*\)</value>|\1|p' 2> /dev/null)
userGroups=$( echo $userGroups | sed 's/, /,/g' )

#Set reload to false to make sure each run
#of this function is a fresh run.  This variable
#is used to let the function know if it needs to
#stop and update JSS instead of checking more.
reload="false"

#Check to see if the JSS EA is null before
#comparing the lists.  If so it will update.
if [ -z "$userGroups" ]; then
	#echo "Computers that need update: ${1}"
	UpdateJSS "${1}" "${membership}"
else 

	#A one to one Comparison of each item
	#in each list to see if an update is needed.
OLDIFS=$IFS
IFS=','
memarr=($membership)
grouparr=($userGroups)
IFS=$OLDIFS
for member in "${memarr[@]}"; do
	if [ "$reload" == "True" ]; then
		break
	fi
	member=$(echo $member | sed 's/\n//g')
	for group in "${grouparr[@]}"; do
		if [ "$member" = "$group" ]; then
			reload="False"
			break
		else
			reload="True"
		fi
done
done
		
fi


#Updates JSS if needed. Passing update
#list to function UpdateJSS along with
#Computer ID and AD Group Membership List.

if [ "$reload" = "True" ]; then
	UpdateJSS "${1}" "${membership}"
fi
}

ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"
    
    echo "$DATE" " $1" >> $LOG
}

#Function to update JSS with new
#AD Group membership lists.
# $1 = JSSComputerID
# $2 = AD Group MemberShip List

UpdateJSS(){

ScriptLogging "Updating: ${1}"


#XML packet to update extension attribute
#with new list of AD Group memberships.

xmlUpdateADMembership="<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>
	<computer>
    	<extension_attributes>
        	<attribute>
            	<name>AD Group Membership</name>
            	<value>"${2}"</value>
        	</attribute>
    	</extension_attributes>
	</computer>"

#Curl statement to JSS to update EA.

theJSSresponse=$( /usr/bin/curl \
--header "Content-Type: text/xml; charset=utf-8" \
--data "${xmlUpdateADMembership}" \
--request PUT \
--connect-timeout 5 \
--max-time 10 \
--user ${jssUser}:${jssPass} \
--insecure \
${jssHost}JSSResource/computers/"id"/$1 2> /dev/null )


}

# Beginning of Procedure

#SQL Query to pull computer ID's
getSQL='select computer_id from computers_denormalized group by computer_id;'
sqlData=$( $mysql_client_path -h$mysql_host -D$mysql_database -u$mysql_user -p$mysql_pass -e "$getSQL" 2< /dev/null)

#Check to make sure there was not an error when Querying SQL
if [[ $? -ne 0 ]]; then
	echo "mysql error"
	exit
fi

#Convert Return of SQL Query Into Array
ComputerID=($sqlData)
read -a ComputerID <<<$sqlData

#Process each ID
for ID in "${ComputerID[@]}"; do
    #Remove First Line "computer_id"
	if [ $ID == "computer_id" ]
	then
		continue
	else
		#Pull User based on computer ID
		userSQL='select username from computers_denormalized where computer_id='$ID';'
		username=$( $mysql_client_path -h$mysql_host -D$mysql_database -u$mysql_user -p$mysql_pass -e "$userSQL" 2< /dev/null)
		userName=`Echo $username | awk '{print $2}'`
		
		#Check user membership with AD
		membership=`dscl /Active\ Directory/BFI/All\ Domains -read /Users/$userName dsAttrTypeNative:memberOf | awk -F'=' {'print $2'} | sed 's/OU//g'`			
			if [ -z "$membership" ]
				then
				#If null user does not exist
				#in AD.
					continue
				else
				#Send ID and Membership list to
				#CheckJSSADMembership function for
				#further checking.
					ScriptLogging "Checking Computer: $ID for User: $userName"
					CheckJSSADMembership "$ID" "${membership}"

			fi
	fi
done

