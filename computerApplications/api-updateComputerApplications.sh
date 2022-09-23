#!/bin/bash

# This script will update Mac Apps (VPP) within Jamf using
# an array of xml files from Github URLs
#
# Created 09.23.2022 @robjschroeder

##################################################
# Variables -- edit as needed

# Jamf Pro API Credentials
jamfProAPIUsername=""
jamfProAPIPassword=""
jamfProURL=""

# Token declarations
token=""
tokenExpirationEpoch="0"

# Public Github URL
pubghURL="https://raw.githubusercontent.com/robjschroeder/JamfOnDeck/main"

# Array of Mac App Store Apps to update from Github to Jamf Pro
computerAppURL=(
	# Evernote
	$pubghURL/computerApplications/Evernote.xml
	# Microsoft Excel
	$pubghURL/computerApplications/Excel.xml
	# Jamf Trust
	$pubghURL/computerApplications/JamfTrust.xml
	# Keynote
	$pubghURL/computerApplications/Keynote.xml
	# Numbers
	$pubghURL/computerApplications/Numbers.xml
	# Microsoft OneDrive
	$pubghURL/computerApplications/OneDrive.xml
	# Microsoft OneNote
	$pubghURL/computerApplications/OneNote.xml
	# Microsoft Outlook
	$pubghURL/computerApplications/Outlook.xml
	# Pages
	$pubghURL/computerApplications/Pages.xml
	# PowerPoint
	$pubghURL/computerApplications/PowerPoint.xml
	# Slack
	$pubghURL/computerApplications/Slack.xml
	# Microsoft Word
	$pubghURL/computerApplications/Word.xml
)

#
##################################################
# Functions -- do not edit below here

# Get a bearer token for Jamf Pro API Authentication
getBearerToken(){
	# Encode credentials
	encodedCredentials=$( printf "${jamfProAPIUsername}:${jamfProAPIPassword}" | /usr/bin/iconv -t ISO-8859-1 | /usr/bin/base64 -i - )
	authToken=$(/usr/bin/curl -s -H "Authorization: Basic ${encodedCredentials}" "${jamfProURL}"/api/v1/auth/token -X POST)
	token=$(/bin/echo "${authToken}" | /usr/bin/plutil -extract token raw -)
	tokenExpiration=$(/bin/echo "${authToken}" | /usr/bin/plutil -extract expires raw - | /usr/bin/awk -F . '{print $1}')
	tokenExpirationEpoch=$(/bin/date -j -f "%Y-%m-%dT%T" "${tokenExpiration}" +"%s")
}

checkTokenExpiration() {
	nowEpochUTC=$(/bin/date -j -f "%Y-%m-%dT%T" "$(/bin/date -u +"%Y-%m-%dT%T")" +"%s")
	if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
		/bin/echo "Token valid until the following epoch time: " "${tokenExpirationEpoch}"
	else
		/bin/echo "No valid token available, getting new token"
		getBearerToken
	fi
}

# Invalidate the token when done
invalidateToken(){
	responseCode=$(/usr/bin/curl -w "%{http_code}" -H "Authorization: Bearer ${token}" ${jamfProURL}/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		/bin/echo "Token successfully invalidated"
		token=""
		tokenExpirationEpoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		/bin/echo "Token already invalid"
	else
		/bin/echo "An unknown error occurred invalidating the token"
	fi
}

# Update computer application configurations from Github to Jamf Pro
putComputerApplications(){
	echo "$(date '+%A %W %Y %X'): Uploading Device app configurations from GitHub..."
	for computerAppConfig in ${computerAppURL[@]}; do
		computerAppConfigData=$(curl --silent $computerAppConfig)
		# Get Computer App Name For Updating Later
		computerAppName=$(echo $computerAppConfigData | xmllint --format - | xmllint --xpath '/mac_application/general/name/text()' -)
		
		# If space in name, we need to make it useable in url
		urlEdAppName=$(echo $computerAppName | sed -e 's/ /%20/g')		
		
		curl --request PUT \
		--url ${jamfProURL}/JSSResource/macapplications/name/${urlEdAppName} \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerAppConfigData}"
		
		sleep 1
	done
	sleep 1
	echo ""
}

#
##################################################
# Script Work
#
#
# Calling all functions

checkTokenExpiration
putComputerApplications
invalidateToken

exit 0
