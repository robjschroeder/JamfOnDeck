#!/bin/bash

# This script will create new computer groups within Jamf using
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

# Array of computer group URLs to upload to Jamf Pro
computerGroupURL=(
	# macOS - Latest OS Supported Ventura
	$pubghURL/computerGroups/macOS-LatestOSSupported-Ventura.xml
	# macOS - Latest OS Supported Monterey
	$pubghURL/computerGroups/macOS-LatestOSSupported-Monterey.xml
	# macOS - Latest OS Supported Catalina
	$pubghURL/computerGroups/macOS-LatestOSSupported-Catalina.xml
	# macOS - Latest OS Supported Big Sur
	$pubghURL/computerGroups/macOS-LatestOSSupported-BigSur.xml
	# FileVault - Bootstrap Not Escrowed In Jamf Pro
	$pubghURL/computerGroups/FileVault-BootstrapNotEscrowedInJamfPro.xml
	# FileVault - Bootstrap Escrowed In Jamf Pro
	$pubghURL/computerGroups/FileVault-BootstrapEscrowedInJamfPro.xml
	# Inventory - Disk Encryption - PRK Not Escrowed
	$pubghURL/computerGroups/FileVaultPRKNotEscrowed.xml
	# Enrollment Method: User Initiated Enrollment
	$pubghURL/computerGroups/EnrollmentMethod-UserInitiatedEnrollment.xml
	# Enrollment Method: Automated Device Enrollment
	$pubghURL/computerGroups/EnrollmentMethod-AutomatedDeviceEnrollment.xml
	# Deployment Rings - Ring 1
	$pubghURL/computerGroups/DeploymentRings-Ring1.xml
	# Deployment Rings - Ring 2
	$pubghURL/computerGroups/DeploymentRings-Ring2.xml
	# Deployment Rings - Ring 3
	$pubghURL/computerGroups/DeploymentRings-Ring3.xml
	# Deployment Rings - Ring 1 - Apple Updates Available
	$pubghURL/computerGroups/DeploymentRings-Ring1-AppleUpdatesAvailable.xml
	# Deployment Rings - Ring 2 - Apple Updates Available
	$pubghURL/computerGroups/DeploymentRings-Ring2-AppleUpdatesAvailable.xml
	# Deployment Rings - Ring 3 - Apple Updates Available
	$pubghURL/computerGroups/DeploymentRings-Ring3-AppleUpdatesAvailable.xml
	# CIS Audit - Out of compliance
	$pubghURL/computerGroups/CISBenchmarksOutOfCompliance.xml
	# Jamf Protect - Screenshot
	$pubghURL/computerGroups/JamfProtectScreenshot.xml
	# Storage - 75% Full
	$pubghURL/computerGroups/Storage75PercentFull.xml
	# Software Updates Available
	$pubghURL/computerGroups/InventorySoftwareUpdatesAvailable.xml
	# Inventory - Hardware - Intel x86
	$pubghURL/computerGroups/InventoryHardwareIntel.xml
	# Inventory - Hardware - Silicon
	$pubghURL/computerGroups/InventoryHardwareSilicon.xml
	# Inventory - Last Check-in > 30 Days
	$pubghURL/computerGroups/InventoryGeneralLastCheckIn30Days.xml
	# Inventory - Computer Name - Needs To Be Renamed
	$pubghURL/computerGroups/InventoryGeneralComputerNeedsRenaming.xml
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

# Create Computer Smart Groups from Github URLs
postComputerGroups(){
	echo "$(date '+%A %W %Y %X'): Uploading Computer Groups from GitHub..."
	for computerGroup in "${computerGroupURL[@]}"; do
		computerGroupData=$(curl --silent $computerGroup)
		curl --request POST \
		--url ${jamfProURL}/JSSResource/computergroups/id/0 \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--header "Authorization: Bearer ${token}" \
		--data "${computerGroupData}"
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
postComputerGroups
invalidateToken

exit 0
