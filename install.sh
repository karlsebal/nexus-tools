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

# This is my fork of corbindavenports script for installing adb and fastboot
# I tried to enhance for exercise.

#!/bin/bash

ADB=""
FASTBOOT=""
UDEV=""
SUDO=""
RULES="no"

XCODE=0

OS=$(uname)
ARCH=$(uname -m)
KERN=$(uname -s)

VERSION="2.5-experimental"

helptext() {
	cat <<-ENDHELP

	usage: $0 [--root] [--install-directory|-d <directory>] [--install-rules|-r]
	
	  -d, --install-directory <directory>	specifies the install-directory

	  -r, --install-rules			install udev-rules

	  -R, --rules-only			install only rules

	  --root 				install in /usr/bin


ENDHELP
}

# download <file> <url>
download() {
	$SUDO curl -o "$1" "$2" -Lfks && 
		echo "[INFO] Download successful." || 
		{ echo "[EROR] Download failed."; XCODE=1; }
}

echo
echo "[INFO] Nexus Tools $VERSION"


## parse options ##

if [[ ("$@" =~ -d || "$@" =~ --install-directory) && "$@" =~ --root ]]; then
	echo "[EROR] you cannot use option --root along with -d"
	echo
	helptext
	exit 1
fi

if [[ ("$@" =~ -R || "$@" =~ --rules-only) && $# -ne 1 ]]; then
	echo "[EROR] option -R|--rules-only does not apply with any other option"
	echo
	helptext
	exit 1
fi

until [ -z "$1" ]; do
	case "$1" in
		"-h" | "--help")
			helptext
			exit 0
			;;
		"-r" | "--install-rules") 
			UDEV="/etc/udev/rules.d/51-android.rules"
			RULES="yes"
			;;
		"-R" | "--rules-only")
			UDEV="/etc/udev/rules.d/51-android.rules"
			RULES="only"
			;;
		"-d")
			if [ -z "$2" ]; then
				echo "[INFO] You did not specify a target directory."
				ADB="${PWD%/}/adb"
				FASTBOOT="${PWD%/}/fastboot"
				echo "[INFO] Using $ADB and $FASTBOOT"
			else
			# using given dir
				ADB="${2%/}/adb"
				FASTBOOT="${2%/}/fastboot"	
				echo "[INFO] Using $ADB and $FASTBOOT"
			fi

			# check dirs
			for dir in $ADB $FASTBOOT; do
				dir=${dir%/*}
				if [ ! -d $dir ]; then
					echo "[EROR] $dir is not a directory or does not exist"
					exit 1
				elif [ ! -w $dir ]; then
					echo "[EROR] $dir is not writable"
					exit 1
				fi
			done
			;;

		"--root")
			ADB="/usr/bin/adb"
			FASTBOOT="/usr/bin/fastboot"
			;;

		*)
			echo "[WARN] Unknown option $1 "
			;;
	esac

	shift
done

# detect operating system
# make urls and infos
# unless -R

if [[ ! "$RULES" == "only" ]]; then
	if [ "$OS" = "Darwin" ]; then # Mac OS X
		INFO="Mac OS X..."
		ADBURL="mac-adb"
		FBURL="mac-fastboot"

	elif [ "${KERN:0:5}" = "Linux" ]; then # Generic Linux

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
			echo "[ERROR] Your CPU platform could not be detected."
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
fi

# Infotext
ADBINFO="[INFO] Downloading ADB for $INFO"
FBINFO="[INFO] Downloading Fastboot for $INFO"
UDEVINFO="[INFO] Downloading udev list..."

# URL
ADBURL="https://github.com/corbindavenport/nexus-tools/raw/master/bin/$ADBURL"
FBURL="https://github.com/corbindavenport/nexus-tools/raw/master/bin/$FBURL"
UDEVURL="https://github.com/corbindavenport/nexus-tools/raw/master/udev.txt"


# if ADB or FASTBOOT is unset, set it both
# unless -R or --rules-only

if [[ ! $RULES == "only" ]]; then
	if [[ -z $ADB || -z $FASTBOOT ]]; then
	# letz see if we have a standard home-bin
		if [[ "$PATH" =~ $HOME/bin ]]; then
			echo "[INFO] Using standard home bin $HOME/bin"
			ADB="$HOME/bin/adb"
			FASTBOOT="$HOME/bin/fastboot"
		else
			echo "[INFO] No standard home bin found. Choosing root."
			ADB="/usr/bin/adb"
			FASTBOOT="/usr/bin/fastboot"
		fi
	fi
fi


# ADB and FASTBOOT not userwritable or UDEV to install
# we need sudo

if [[  (! ( -w "${ADB%/*}" && -w "${FASTBOOT%/*}" ) || ( -n "$UDEV" )) ]]; then
	SUDO="sudo"
	echo "[INFO] Install as root"
	# get sudo
	echo "[INFO] Please enter sudo password for install."
	sudo echo "[ OK ] Sudo access granted." || { echo "[EROR] No sudo access."; exit 1; }
fi


# install
# udev

if [ -n "$UDEV" ]; then
	echo "$UDEVINFO"

	if [ ! -d /etc/udev/rules.d/ ]; then
	    sudo mkdir -p /etc/udev/rules.d/
	fi

	download "$UDEV" "$UDEVURL"
	sudo chmod 644 $UDEV
	sudo chown root: $UDEV 2>/dev/null
	sudo service udev restart 2>/dev/null
	sudo killall adb 2>/dev/null
fi

[[ "$RULES" == "only" ]] && { echo Done.; exit 0; }


echo "[INFO] Installing $ADB and $FASTBOOT"

# adb

if [ -f $ADB ]; then
    read -n1 -p "[WARN] ADB is already present, press ENTER to remove or x to cancel." input
	[ -z "$input" ] && $SUDO rm $ADB || exit 1
fi

echo "$ADBINFO"
download "$ADB" "$ADBURL"
	

# fastboot

if [ -f $FASTBOOT ]; then
    read -n1 -p "[WARN] Fastboot is already present, press ENTER to remove or x to cancel." input
    [ -z "$input" ] && $SUDO rm $FASTBOOT || exit 1
fi

echo "$FBINFO"
download "$FASTBOOT" "$FBURL"



# set executable

echo "[INFO] Set $ADB executable"
$SUDO chmod +x "$ADB"

echo "[INFO] Set $FASTBOOT executable"
$SUDO chmod +x "$FASTBOOT"

echo "----"

if [ -z $XCODE ]; then
	echo "Done. Type adb or fastboot to run."
else
	echo "Done. But something went wrong."
fi

echo
exit $XCODE
