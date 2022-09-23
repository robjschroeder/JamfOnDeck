#!/bin/bash

# This script will create new mobile device groups within Jamf using
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

# Array of mobile groups to upload to Jamf Pro
mobileGroupURL=(
	# Inventory - Available Space - Less than 4GB
	$pubghURL/mobileDeviceGroups/InventoryAvailableSpaceLessThan4GB.xml
	# Inventory - Available Space - Less than 75%
	$pubghURL/mobileDeviceGroups/InventoryAvailableSpaceLessThan75.xml
	# Inventory - General - Supervised
	$pubghURL/mobileDeviceGroups/InventoryGeneralSupervised.xml
	# Inventory - General - Unsupervised
	$pubghURL/mobileDeviceGroups/InventoryGeneralUnsupervised.xml
	# Inventory - Last Update - 30 Days
	$pubghURL/mobileDeviceGroups/InventoryLastUpdate30Days.xml
	# Inventory - Security - Jailbreak Detected
	$pubghURL/mobileDeviceGroups/InventorySecurityJailbreakDetected.xml
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

# Create device groups from Github to Jamf Pro
postMobileDeviceGroups(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Groups from GitHub..."
	for deviceGroup in "${mobileGroupURL[@]}"; do
		deviceGroupData=$(curl --silent $deviceGroup)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/mobiledevicegroups/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${deviceGroupData}"
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
postMobileDeviceGroups
invalidateToken

exit 0
