#!/bin/bash

# This script will create new computer extension attributes 
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

# Array of computer extension attribute URLs to upload to Jamf Pro
computerExtAttributeURL=(
	# APNs Topic ID
	$pubghURL/computerExtensionAttributes/APNsTopicID.xml
	# Bootstrap Token
	$pubghURL/computerExtensionAttributes/BootstrapToken.xml
	# CIS Audit Count
	$pubghURL/computerExtensionAttributes/CISAuditCount.xml
	# CIS Audit List
	$pubghURL/computerExtensionAttributes/CISAuditList.xml
	# Computer Name Matches Serial
	$pubghURL/computerExtensionAttributes/ComputerNameMatchesSerial.xml
	# Deployment Ring
	$pubghURL/computerExtensionAttributes/DeploymentRing.xml
	# Jamf Connect Login Window Mechanism
	$pubghURL/computerExtensionAttributes/JamfConnectLoginWindowMech.xml
	# Jamf Connect Version
	$pubghURL/computerExtensionAttributes/JamfConnectVersion.xml
	# Jamf Protect - Insights
	$pubghURL/computerExtensionAttributes/JamfProtectCheckIn.xml
	# Jamf Protect - Insights Check-In
	$pubghURL/computerExtensionAttributes/JamfProtectInsightsCheckIn.xml
	# Jamf Protect - Smart Groups
	$pubghURL/computerExtensionAttributes/JamfProtectSmartGroups.xml
	# Jamf Protect - Threat Prevention Version
	$pubghURL/computerExtensionAttributes/JamfProtectThreatPreventionVersion.xml
	# Last User
	$pubghURL/computerExtensionAttributes/LastUser.xml
	# Latest OS Supported
	$pubghURL/computerExtensionAttributes/LatestOSSupported.xml
	# Network Quality
	$pubghURL/computerExtensionAttributes/NetworkQuality.xml
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

# Create Computer Extension Attributes from Github URLs
postComputerExtensionAttributes(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Extension Attributes from GitHub..."
	for computerExtAttribute in "${computerExtAttributeURL[@]}"; do
		# Get the extension attirbute data
		computerExtAttributeData=$(curl --silent $computerExtAttribute)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/computerextensionattributes/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerExtAttributeData}"
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
postComputerExtensionAttributes
invalidateToken

exit 0
