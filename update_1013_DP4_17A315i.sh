#!/bin/sh
#
# Bash script to download macOS High Sierra update packages from sucatalog.gz and build the installer.pkg for it.
#
# version 1.7 - Copyright (c) 2017 by Pike R. Alpha (PikeRAlpha@yahoo.com)
#
# Updates:
#
# 			- Creates a seedEnrollement.plist when missing.
# 			- Volume picker for seedEnrollement.plist added.
# 			- Added sudo to 'open installer.pkg' to remedy authorisation problems.
# 			- Fix for volume names with a space in it. Thanks to:
# 			- https://pikeralpha.wordpress.com/2017/06/22/script-to-upgrade-macos-high-sierra-dp1-to-dp2/#comment-10216)
# 			- Add file checks so that we only download the missing files.
# 			- Polished up comments.
# 			- Changed key, salt, target files and version (now v1.5).
# 			- Changed key, salt, target files and version (now v1.6).
# 			- Opt out for firmware added.
# 			- Catch installer failure.
# 			- Improved verbose output.
# 			- Changed version number (now v1.7).
#

# CatalogURL for Developer Program Members
# https://swscan.apple.com/content/catalogs/others/index-10.13seed-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz
#
# CatalogURL for Beta Program Members
# https://swscan.apple.com/content/catalogs/others/index-10.13beta-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz
#
# CatalogURL for Regular Software Updates
# https://swscan.apple.com/content/catalogs/others/index-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz

#
# Tip: In case you run into the ERROR_7E7AEE96CA error then you need to change the ProductVersion and 
# in /System/Library/CoreServices/SystemVersion.plist to 10.13
#

#
# You may need VolumeCheck() to return true (and thus skip checks)
#
export __OS_INSTALL=1

#
# Skip firmware update.
#
export __FIRMWARE_UPDATE_OPTOUT

#
# Personalization setting.
#
#export __OSIS_ENABLE_SECUREBOOT

#
# Initialisation of a variable.
#
let index=0

#
# Change additional shell optional behavior (expand unmatched names to a null string).
#
shopt -s nullglob

#
# Change to Volumes folder.
#
cd /Volumes

#
# Collect available target volume names.
#
targetVolumes=(*)

echo "\nAvailable target volumes:\n"

for volume in "${targetVolumes[@]}"
  do
    echo "[$index] ${volume}"
    let index++
done

echo ""

#
# Ask to select a target volume.
#
read -p "Select a target volume for the boot file: " volumeNumber

#
# Path to target volume.
#
targetVolume="/Volumes/${targetVolumes[$volumeNumber]}"

#
# Catching an installer failure.
#
checksum=$(shasum "${targetVolume}/System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox" | awk '{ print $1 }')

if [[ "${checksum}" != "3bebbbdb3ef75b355cdae1c0badc4da52c2a8dce" ]];
  then
    printf "Error: Target drive does NOT fit the expected version of High Sierra. Exiting ...\nDone."
    exit -1
fi

#
# Path to enrollment plist.
#
seedEnrollmentPlist="${targetVolume}/Users/Shared/.SeedEnrollment.plist"

#
# Write enrollement plist when missing (seed program options: CustomerSeed, DeveloperSeed or PublicSeed).
#
if [ ! -e "${seedEnrollmentPlist}" ]
  then
    echo '<?xml version="1.0" encoding="UTF-8"?>'																	>  "${seedEnrollmentPlist}"
    echo '<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'	>> "${seedEnrollmentPlist}"
    echo '<plist version="1.0">'																					>> "${seedEnrollmentPlist}"
    echo '	<dict>'																									>> "${seedEnrollmentPlist}"
    echo '		<key>SeedProgram</key>'																				>> "${seedEnrollmentPlist}"
    echo '		<string>DeveloperSeed</string>'																		>> "${seedEnrollmentPlist}"
    echo '	</dict>'																								>> "${seedEnrollmentPlist}"
    echo '</plist>'																									>> "${seedEnrollmentPlist}"
fi

#
# Target key for update copied from sucatalog.gz (think CatalogURL).
#
key="091-23859"

#
# Initialisation of a variable (our target folder).
#
tmpDirectory="/tmp"

#
# Name of target installer package
#
installerPackage="installer.pkg"

#
# URL copied from sucatalog.gz (think CatalogURL).
#
url="https://swdist.apple.com/content/downloads/43/54/${key}/f4y3g1nnbf61pv2wvnibcpswwjd7i1bxy8/"

#
# Target distribution language.
#
distribution="${key}.English.dist"

#
# Target files copied from sucatalog.gz (think CatalogURL).
#
targetFiles=(
FirmwareUpdate.pkg
FullBundleUpdate.pkg
EmbeddedOSFirmware.pkg
macOSUpd10.13.pkg
macOSUpd10.13Patch.pkg
macOSUpd10.13.RecoveryHDUpdate.pkg
)

#
# Check target directory.
#
if [ ! -d "${tmpDirectory}/${key}" ]
  then
    mkdir "${tmpDirectory}/${key}"
fi

#
# Download distribution file
#
if [ ! -e "${tmpDirectory}/${key}/${distribution}" ];
  then
    echo "Downloading: ${distribution} ..."
    curl "${url}${distribution}" -o "${tmpDirectory}/${key}/${distribution}"
  else
    echo "File: ${distribution} already there, skipping download."
fi

#
# Change to working directory (otherwise it will fail to locate the packages).
#
cd "${tmpDirectory}/${key}"

#
# Reset index variable.
#
let index=0

#
# Download target files.
#
for filename in "${targetFiles[@]}"
  do
    if [ ! -e "${tmpDirectory}/${key}/${filename}" ];
      then
        echo "Downloading: ${filename} ..."
        curl "${url}${filename}" -o "${tmpDirectory}/${key}/${filename}"
      else
        echo "File: ${filename} already there, skipping download."
    fi

    let index++
  done

#
# Create installer package.
#
echo "Creating installer.pkg ..."
productbuild --distribution "${tmpDirectory}/${key}/${distribution}" --package-path "${tmpDirectory}/${key}" "${installerPackage}"

#
# Launch the installer.
#
if [ -e "${tmpDirectory}/${key}/${installerPackage}" ]
  then
    echo "Running installer ..."
    sudo /usr/sbin/installer -pkg "${tmpDirectory}/${key}/${installerPackage}" -target "${targetVolume}"
fi
