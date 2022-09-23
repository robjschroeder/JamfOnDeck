#!/bin/bash

# This script will create new scripts within Jamf using
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

# Array of scripts URLs to upload to Jamf Pro
computerScriptsURL=(
	# Applications - Installomator
	$pubghURL/scripts/Applications-Installomator.xml
	# Enrollment - Start DEPNotify
	$pubghURL/scripts/Enrollment-StartDEPNotify.xml
	# CIS Benchmarks - Set Org Priorities
	$pubghURL/scripts/CISSetOrgPriorities.xml
	# CIS Benchmarks - Audit Compliance
	$pubghURL/scripts/CISBenchmarksAuditCompliance.xml
	# CIS Benchmarks - Security Remediation
	$pubghURL/scripts/CISBenchmarksRemediation.xml
	# Maintenance - Environment Test
	$pubghURL/scripts/MaintenanceEnvironmentTest.xml
	# Jamf Protect - Screenshot Remediation
	$pubghURL/scripts/JamfProtectScreenshot.xml
	# Inventory - Recon At Reboot
	$pubghURL/scripts/InventoryReconAtReboot.xml
	# Inventory - Rename Computer
	$pubghURL/scripts/InventoryRenameComputer.xml
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

# Create computer scripts from Github to Jamf Pro
postScripts(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Scripts from GitHub..."
	for computerScript in "${computerScriptsURL[@]}"; do
		computerScriptData=$(curl --silent $computerScript)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/scripts/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerScriptData}"
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
postScripts
invalidateToken

exit 0
