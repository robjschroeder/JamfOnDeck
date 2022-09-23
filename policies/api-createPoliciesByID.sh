#!/bin/bash

# This script will create new policies within Jamf using
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

# Array of policy URLs to upload to Jamf Pro
computerPoliciesURL=(
	# Applications - Instsall - Adobe Creative Cloud - Self Service
	$pubghURL/policies/ApplicationsInstallAdobeCreativeCloudDesktopSelfService.xml
	# Applications - Install - Adobe Reader DC - Self Service
	$pubghURL/policies/ApplicationsInstallAdobeReaderDCSelfService.xml
	# Applications - Install - Blue Jeans - Self Service
	$pubghURL/policies/ApplicationsInstallBlueJeansSelfService.xml
	# Applications - Install - Citrix Workspace - Self Service
	$pubghURL/policies/ApplicationsInstallCitrixWorkspaceSelfService.xml
	# Applications - Install - DEP Notify
	$pubghURL/policies/ApplicationsInstallDEPNotify.xml
	# Applications - Install - Dropbox - Self Service
	$pubghURL/policies/ApplicationsInstallDropboxSelfService.xml
	# Applications - Install - Firefox - Self Service
	$pubghURL/policies/ApplicationsInstallFirefoxSelfService.xml
	# Applications - Install - Github Desktop - Self Service
	$pubghURL/policies/ApplicationsInstallGithubDesktopSelfService.xml
	# Applications - Install - GoToMeeting - Self Service
	$pubghURL/Cpolicies/ApplicationsInstallGoToMeetingSelfService.xml
	# Applications - Install - Google Chrome - Self Service
	$pubghURL/policies/ApplicationsInstallGoogleChromeSelfService.xml
	# Applications - Install - Google Drive - Self Service
	$pubghURL/policies/ApplicationsInstallGoogleDriveSelfService.xml
	# Applications - Install - Libre Office - Self Service
	$pubghURL/Cpolicies/ApplicationsInstallLibreOfficeSelfService.xml
	# Applications - Install - Microsoft Edge - Self Service
	$pubghURL/policies/ApplicationsInstallMicrosoftEdgeSelfService.xml
	# Applications - Install - Sketch - Self Service
	$pubghURL/policies/ApplicationsInstallSketchSelfService.xml
	# Applications - Install - Sublime Text - Self Service
	$pubghURL/policies/ApplicationsInstallSublimeTextSelfService.xml
	# Applications - Install - Microsoft Teams - Self Service
	$pubghURL/policies/ApplicationsInstallTeamsSelfService.xml
	# Applications - Install - VMWare Horizon - Self Service
	$pubghURL/policies/ApplicationsInstallVMWareHorizonSelfService.xml
	# Applications - Install - WebEx - Self Service
	$pubghURL/policies/ApplicationsInstallWebExSelfService.xml
	# Applications - Instasll - Zoom - Self Service
	$pubghURL/policies/ApplicationsInstallZoomSelfService.xml
	# Inventory - Recon At Reboot
	$pubghURL/policies/InventoryReconAtReboot.xml
	# Inventory - Rename Computer
	$pubghURL/policies/InventoryRenameComputer.xml
	# Maintenance - User Environment Test - Self Service
	$pubghURL/policies/MaintenanceUserEnvironmentTestSelfService.xml
	# Security - CIS Benchmarks - All 3
	$pubghURL/policies/SecurityCISBenchmarks.xml
	# Security - CIS Benchmarks - Remeddiate
	$pubghURL/policies/SecurityCISBenchmarksRemediate.xml
	# Security - Jamf Protect - Screenshot
	$pubghURL/policies/SecurityJamfProtectScreenshot.xml
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

# Create computer policies from Github to Jamf Pro
postPolicies(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Policies from GitHub..."
	for computerPolicy in "${computerPoliciesURL[@]}"; do
		computerPolicyData=$(curl --silent $computerPolicy)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/policies/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerPolicyData}"
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
postPolicies
invalidateToken

exit 0
