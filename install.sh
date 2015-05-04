#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#!/bin/bash

# TODO check success

ADB=""
FASTBOOT=""
UDEV=""

OS=$(uname)
ARCH=$(uname -m)
KERN=$(uname -s)

helptext() {
	cat <<-ENDHELP

	usage: $0 [-d directory] [-b]
	
	  -d, --install-directory [directory]	specifies the install-directory

	  -r, --install-rules			install udev-rules

	  --root 				install in /usr/bin

ENDHELP
}


## parse options ##

until [ -z "$1" ]; do
	case "$1" in
		"-h" | "--help")
			helptext
			exit 0
			;;
		"-r" | "--install-rules")
			UDEV="/etc/udev/rules.d/51-android.rules"
			;;
		"-d")
			# TODO simplify
			if [ -z "$2" ]; then
			# no dir given, using PWD 
				ADB="${PWD%/}/adb"
				FASTBOOT="${PWD%/}/fastboot"
			else
			# using given dir
				ADB="${2%/}/adb"
				FASTBOOT="${2%/}/fastboot"	
				
				# check dirs
				for dir in $ADB $FASTBOOT; do
					dir=${dir%/*}
					if [ ! -d $dir ]; then
						echo "[ERROR] $dir is not a directory or does not exist"
						exit 1
					elif [ ! -w $dir ]; then
						echo "[ERROR] $dir is not writable"
						exit 1
					fi
				done

			fi
			;;

		"--root")
			ADB="/usr/bin/adb"
			FASTBOOT="/usr/bin/fastboot"
			;;
	esac

	shift
done

# if ADB or FASTBOOT is unset, set it both
if [ -z $ADB -o -z $FASTBOOT ]; then
	# letz see if we have a standard home-bin
	if [[ "$PATH" =~ $HOME/bin ]]; then
		echo [INFO] Using standard home bin $HOME/bin
		ADB="$HOME/bin/adb"
		FASTBOOT="$HOME/bin/fastboot"
	else
		echo [INFO] No standard home bin found. Choosing root.
		ADB="/usr/bin/adb"
		FASTBOOT="/usr/bin/fastboot"
	fi
fi

set -x
# ADB and FASTBOOT not userwritable or UDEV to install
if [[ ! (( -w "${ADB%/*}" && -w "${FASTBOOT%/*}" ) || ( -n "$UDEV" )) ]]; then
	SUDO="sudo"
	echo "[INFO] Install as root"
	# get sudo
	echo "[INFO] Please enter sudo password for install."
	sudo echo "[ OK ] Sudo access granted." || { echo "[ERROR] No sudo access!!"; exit 1; }
fi
set +x


## letzgo!

echo "[INFO] Nexus Tools 2.5-experimental"
echo "[INFO] Installing $ADB and $FASTBOOT"

# detect operating system and 
# make urls and infos

if [ "$OS" = "Darwin" ]; then # Mac OS X
	INFO="Mac OS X..."
	ADBURL="mac-adb"
	FBURL="mac-fastboot"

elif [ "$(expr substr $KERN 1 5)" = "Linux" ]; then # Generic Linux

	if [ "$ARCH" = "i386" ] || [ "$ARCH" = "i486" ] || 
		[ "$ARCH" = "i586" ] || [ "$ARCH" = "amd64" ] ||
		[ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i686" ]; then # Linux on Intel x86/x86_64 CPU
		INFO="Linux [Intel CPU]..."
		ADBURL="linux-i386-adb"
		FBURL="linux-i386-fastboot"

	elif [ "$ARCH" = "arm" ] || [ "$ARCH" = "armv6l" ]; then # Linux on ARM CPU
		echo "[WARN] The ADB binaries for ARM are out of date, and do not work on Android 4.2.2+"
		INFO="Linux [ARM CPU]..."
		ADBURL="linux-arm-adb"
		FBURL="linux-arm-fastboot"

	else
		echo "[EROR] Your CPU platform could not be detected."
	        echo " "
       		exit 1
	fi
else
	echo "[EROR] Your operating system or architecture could not be detected."
	echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
	echo "[EROR] Report the following information in the bug report:"
	echo "[EROR] OS: $OS"
	echo "[EROR] ARCH: $ARCH"
	echo " "
	exit 1
fi

# Infotext
ADBINFO="[INFO] Downloading ADB for $INFO"
FBINFO="[INFO] Downloading Fastboot for $INFO"
UDEVINFO="[INFO] Downloading udev list..."

# URL
ADBURL="http://github.com/corbindavenport/nexus-tools/raw/master/$ADBURL"
FBURL="http://github.com/corbindavenport/nexus-tools/raw/master/$FBURL"
UDEVURL="http://github.com/corbindavenport/nexus-tools/raw/master/udev.txt"

# check if already installed

if [ -f $ADB ]; then
    read -n1 -p "[WARN] ADB is already present, press ENTER to overwrite or exit to cancel." input
    [ "$input" = "" ] && $SUDO rm $ADB || exit 1
fi
if [ -f $FASTBOOT ]; then
    read -n1 -p "[WARN] Fastboot is already present, press ENTER to overwrite or exit to cancel." input
    [ "$input" = "" ] && $SUDO rm $FASTBOOT || exit 1
fi

# install

echo "$ADBINFO"
$SUDO curl -s -o "$ADB" "$ADBURL" -LOk

echo "$FBINFO"
$SUDO curl -s -o "$FASTBOOT" "$FBURL" -LOk

echo "$UDEVINFO"
    if [ -n "$UDEV" ]; then
        if [ ! -d /etc/udev/rules.d/ ]; then
            sudo mkdir -p /etc/udev/rules.d/
        fi
	sudo curl -s -o "$UDEV" "$UDEVURL" -LOk
        sudo chmod 644 $UDEV
        sudo chown root. $UDEV 2>/dev/null
        sudo service udev restart 2>/dev/null
        sudo killall adb 2>/dev/null
    fi

echo "[INFO] Making ADB and Fastboot executable..."
echo $ADB
echo $FASTBOOT
echo ----
$SUDO chmod +x "$ADB"
$SUDO chmod +x "$FASTBOOT"

echo "[ OK ] Done!"
echo "[INFO] Type adb or fastboot to run."
echo " "
exit 0
