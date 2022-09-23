#!/bin/bash

# This script will create new osx configuration profiles 
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

# Array of configuration profiles URLs to upload to Jamf Pro
computerConfigURL=(
  # Apple Software Updates - Ring 1
  $pubghURL/osxConfigurationProfiles/SoftwareUpdates-Ring1.xml
  # Apple Software Updates - Ring 2
  $pubghURL/osxConfigurationProfiles/SoftwareUpdates-Ring2.xml
  # Apple Software Updates - Ring 3
  $pubghURL/osxConfigurationProfiles/SoftwareUpdates-Ring3.xml
	# Security and Privacy - FileVault
	$pubghURL/osxConfigurationProfiles/SecurityAndPrivacy-FileVault.xml
	# Apple Software Updates
	$pubghURL/osxConfigurationProfiles/AppleSoftwareUpdates.xml
	# Apple Firewall
	$pubghURL/osxConfigurationProfiles/SecurityFirewall.xml
	# Security Login Window Disable Guest User
	$pubghURL/osxConfigurationProfiles/SecurityLoginWindowDisableGuestUser.xml
	# CIS Benchmarks - 4.1 Disable Bonjour Advertising Services
	$pubghURL/osxConfigurationProfiles/CISBenchmarksDisableBonjourAdvertisingServices.xml
	# CIS Benchmarks - 2.5.9 Enable Limit Ad Tracking
	$pubghURL/osxConfigurationProfiles/CISBenchmarksEnableLimitAdTracking.xml
	# CIS Benchmarks - 2.5.6 Ensure Limit Ad Tracking
	$pubghURL/osxConfigurationProfiles/CISBenchmarksEnsureLimitAdTracking.xml
	# Security Gatekeeper
	$pubghURL/osxConfigurationProfiles/SecurityGatekeeper.xml
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

# Upload computer configuration profiles from Github to Jamf Pro
postOSXConfigurationProfiles(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Configuration Profiles from GitHub..."
	for computerConfig in ${computerConfigURL[@]}; do
		computerConfigData=$(curl --silent $computerConfig)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/osxconfigurationprofiles/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerConfigData}"
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
postOSXConfigurationProfiles
invalidateToken

exit 0
