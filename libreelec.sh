#!/bin/sh
# Script for installing Hyperion.NG release on LibreElec
# Examples of usage:
# Download and install latest Hyperion.NG release:	libreelec.sh
# Download an specific Hyperion.NG release:		libreelec.sh 2.0.0-alpha.6
# Install an specific Hyperion.NG release tar.gz file:	libreelec.sh /storage/deploy/Hyperion-2.0.0-alpha.7-Linux-armv7l.tar.gz

#Set welcome message
echo '*******************************************************************************' 
echo 'This script will install Hyperion.NG on LibreELEC'
echo 'Created by brindosch and modified by Paulchen-Panther (thanks to horschte from kodinerds)'
echo 'hyperion-project.org - the official Hyperion source'
echo '*******************************************************************************'

# Find out if we are on LibreELEC
OS_LIBREELEC=`grep -m1 -c LibreELEC /etc/issue`
# Check that
if [ $OS_LIBREELEC -ne 1 ]; then
	echo '---> Critical Error: We are not on LibreELEC -> abort'
	exit 1
fi

# Find out if we are on an Raspberry Pi or x86_64
CPU_RPI=`grep -m1 -c 'BCM2708\|BCM2709\|BCM2710\|BCM2835\|BCM2836\|BCM2837\|BCM2711\|Raspberry Pi 5' /proc/cpuinfo`
CPU_x86_64=`grep -m1 -c 'Intel\|AMD' /proc/cpuinfo`
# Check that
if [ $CPU_RPI -ne 1 ] && [ $CPU_x86_64 -ne 1 ]; then
	echo '---> Critical Error: We are not on an Raspberry Pi or an x86_64 CPU -> abort'
	exit 1
fi

#Check which RPi we are one (in case)
RPI_1=`grep -m1 -c 'BCM2708' /proc/cpuinfo`
RPI_2_3_4=`grep -m1 -c 'BCM2709\|BCM2710\|BCM2835\|BCM2836\|BCM2837\|BCM2711' /proc/cpuinfo`
RPI_5=`grep -m1 -c 'Raspberry Pi 5' /proc/cpuinfo`
Intel=`grep -m1 -c 'Intel' /proc/cpuinfo`
AMD=`grep -m1 -c 'AMD' /proc/cpuinfo`

# check which init script we should use
USE_SYSTEMD=`grep -m1 -c systemd /proc/1/comm`

# Make sure that the boblight daemon is no longer running
BOBLIGHT_PROCNR=$(pidof boblightd | wc -l)
if [ $BOBLIGHT_PROCNR -eq 1 ]; then
	echo '---> Critical Error: Found running instance of boblight. Please stop boblight via Kodi menu before installing Hyperion.NG -> abort'
	exit 1
fi

#Check, if dtparam=spi=on is in place (just for RPi)
if [ $CPU_RPI -eq 1 ]; then
	SPIOK=`grep '^\dtparam=spi=on' /flash/config.txt | wc -l`
	if [ $SPIOK -ne 1 ]; then
		mount -o remount,rw /flash
		echo '---> RPi with LibreELEC found, but SPI is not set, we write "dtparam=spi=on" to /flash/config.txt'
		sed -i '$a dtparam=spi=on' /flash/config.txt
		mount -o remount,ro /flash
		REBOOTMESSAGE="echo Please reboot LibreELEC, we inserted dtparam=spi=on to /flash/config.txt"
	fi
fi

# Check if the argument is not an local file
if [ ! -f "$1" ]; then
	# Select the appropriate download path
	HYPERION_DOWNLOAD_URL="https://github.com/hyperion-project/hyperion.ng/releases/download"
	HYPERION_RELEASES_URL="https://api.github.com/repos/hyperion-project/hyperion.ng/releases"

	# Get the latest version or use the specified version
	if [ -z "$1" ]; then
		HYPERION_LATEST_VERSION=$(curl -sL "$HYPERION_RELEASES_URL" | grep "tag_name" | head -1 | cut -d '"' -f 4)
	else
		HYPERION_LATEST_VERSION="$1"
	fi

	if [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.1" ] || \
	   [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.2" ] || \
	   [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.3" ] || \
	   [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.4" ] || \
	   [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.5" ]
	then
		if [ $CPU_RPI -eq 1 ]; then
			HYPERION_SUFFIX="hf-rpi"
		elif [ $CPU_x86_64 -eq 1 ]; then
			HYPERION_SUFFIX="amd64-x11"
		fi
	else
		if [ $CPU_RPI -eq 1 ]; then
			HYPERION_SUFFIX="l"
		elif [ $CPU_x86_64 -eq 1 ]; then
			HYPERION_SUFFIX="x86_64"
		fi
	fi;

	# Select the appropriate release
	if [ $RPI_1 -eq 1 ]; then
		HYPERION_RELEASE=$HYPERION_DOWNLOAD_URL/$HYPERION_LATEST_VERSION/Hyperion-$HYPERION_LATEST_VERSION-Linux-armv6$HYPERION_SUFFIX.tar.gz
	elif [ $RPI_2_3_4 -eq 1 ]; then
		HYPERION_RELEASE=$HYPERION_DOWNLOAD_URL/$HYPERION_LATEST_VERSION/Hyperion-$HYPERION_LATEST_VERSION-Linux-armv7$HYPERION_SUFFIX.tar.gz
    elif [ $RPI_5 -eq 1 ]; then
		HYPERION_RELEASE=$HYPERION_DOWNLOAD_URL/$HYPERION_LATEST_VERSION/Hyperion-$HYPERION_LATEST_VERSION-Linux-aarch64$HYPERION_SUFFIX.tar.gz
	elif [ $Intel -eq 1 ] || [ $AMD -eq 1 ]; then
		HYPERION_RELEASE=$HYPERION_DOWNLOAD_URL/$HYPERION_LATEST_VERSION/Hyperion-$HYPERION_LATEST_VERSION-Linux-$HYPERION_SUFFIX.tar.gz
	else
		echo "---> Critical Error: Target platform unknown -> abort"
		exit 1
	fi

	# Get and extract Hyperion.NG
	echo "---> Downloading release: $HYPERION_RELEASE"
	curl -# -L --get $HYPERION_RELEASE | tar --strip-components=1 -C /storage share/hyperion -xz

	# Delete unused dependencies on alpha 7
	if [ "$HYPERION_LATEST_VERSION" = "2.0.0-alpha.7" ]; then
		rm /storage/hyperion/lib/libcec*
		rm /storage/hyperion/lib/libz*
	fi
else
	echo "---> Extract local file: $1"
	tar -xzf "$1" --strip-components=1 -C /storage share/hyperion/
fi

#set the executen bit (failsave)
chmod +x -R /storage/hyperion/bin

# Create the service control configuration
echo '---> Installing systemd script'
SERVICE_CONTENT="[Unit]
Description=Hyperion ambient light systemd service
After=network.target

[Service]
Environment=DISPLAY=:0.0
ExecStart=/storage/hyperion/bin/hyperiond --userdata /storage/hyperion/
TimeoutStopSec=2
Restart=always
RestartSec=10

[Install]
WantedBy=default.target"

# Place startup script for systemd and activate
echo "$SERVICE_CONTENT" > /storage/.config/system.d/hyperion.service
systemctl -q enable hyperion.service --now

echo '*******************************************************************************' 
echo 'Hyperion.NG installation finished!'
$REBOOTMESSAGE
echo '*******************************************************************************' 

exit 0