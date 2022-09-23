#!/bin/bash

# This script will update mobile device app (VPP) configurations
# within Jamf using an array of xml files from Github URLs
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

# Array of mobile app configurations to update from Github to Jamf Pro
mobileAppURL=(
	# Adobe Acrobat Reader
	$pubghURL/mobileDeviceApplications/AdobeAcrobatReader.xml
	# Adobe Creative Cloud
	$pubghURL/mobileDeviceApplications/AdobeCreativeCloud.xml
	# Blue Jeans
	$pubghURL/mobileDeviceApplications/BlueJeans.xml
	# Citrix Workspace
	$pubghURL/mobileDeviceApplications/CitrixWorkspace.xml
	# Dropbox
	$pubghURL/mobileDeviceApplications/Dropbox.xml
	# Evernote
	$pubghURL/mobileDeviceApplications/Evernote.xml
	# Firefox
	$pubghURL/mobileDeviceApplications/Firefox.xml
	# Github
	$pubghURL/mobileDeviceApplications/Github.xml
	# GoToMeeting
	$pubghURL/mobileDeviceApplications/GoToMeeting.xml
	# Google Chrome
	$pubghURL/mobileDeviceApplications/GoogleChrome.xml
	# Google Drive
	$pubghURL/mobileDeviceApplications/GoogleDrive.xml
	# Jamf Reset
	$pubghURL/mobileDeviceApplications/JamfReset.xml
	# Jamf Self Service
	$pubghURL/mobileDeviceApplications/JamfSelfService.xml
	# Jamf Setup
	$pubghURL/mobileDeviceApplications/JamfSetup.xml
	# Keynote
	$pubghURL/mobileDeviceApplications/Keynote.xml
	# Microsoft Edge
	$pubghURL/mobileDeviceApplications/MicrosoftEdge.xml
	# Microsoft Excel
	$pubghURL/mobileDeviceApplications/MicrosoftExcel.xml
	# Microsoft OneDrive
	$pubghURL/mobileDeviceApplications/MicrosoftOneDrive.xml
	# Microsoft OneNote
	$pubghURL/mobileDeviceApplications/MicrosoftOneNote.xml
	# Microsoft Outlook
	$pubghURL/mobileDeviceApplications/MicrosoftOutlook.xml
	# Microsoft PowerPoint
	$pubghURL/mobileDeviceApplications/MicrosoftPowerPoint.xml
	# Microsoft Teams
	$pubghURL/mobileDeviceApplications/MicrosoftTeams.xml
	# Microsoft Word
	$pubghURL/mobileDeviceApplications/MicrosoftWord.xml
	# Numbers
	$pubghURL/mobileDeviceApplications/Numbers.xml
	# Pages
	$pubghURL/mobileDeviceApplications/Pages.xml
	# Slack
	$pubghURL/mobileDeviceApplications/Slack.xml
	# VMWare Horizon Client
	$pubghURL/mobileDeviceApplications/VMWareHorizonClient.xml
	# Webex Meetings
	$pubghURL/mobileDeviceApplications/WebexMeetings.xml
	# Zoom
	$pubghURL/mobileDeviceApplications/Zoom.xml
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

# Updates mobile device app configurations from GitHub to Jamf Pro
putMobileDeviceApplications(){
	echo "$(date '+%A %W %Y %X'): Uploading Device app configurations from GitHub..."
	for mobileAppConfig in ${mobileAppURL[@]}; do
		mobileAppConfigData=$(curl --silent $mobileAppConfig)
		# Get Mobile App Name For Updating Later
		mobileAppBundleID=$(echo $mobileAppConfigData | xmllint --format - | xmllint --xpath '/mobile_device_application/general/bundle_id/text()' -)
		
		
		curl --request PUT \
		--url ${jamfProURL}/JSSResource/mobiledeviceapplications/bundleid/${mobileAppBundleID} \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${mobileAppConfigData}"
		
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
putMobileDeviceApplications
invalidateToken

exit 0
