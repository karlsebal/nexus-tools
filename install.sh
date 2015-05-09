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

BASEURL="http://github.com/corbindavenport/nexus-tools/raw/master"

OS=$(uname)
ARCH=$(uname -m)
KERN=$(uname -s)

VERSION="2.5-us"

helptext() {
	cat <<-ENDHELP

	usage: $0 [--root] [--install-directory|-d <directory>] [--install-rules|-r]
	
	  -d, --install-directory <directory>	specifies the install-directory

	  -r, --install-rules			install udev-rules

	  -R, --rules-only			install udev-rules only

	  --root 				install in /usr/bin

	
	${0##*/} defaults to install into <userhome>/bin if found, if not it will
	choose /usr/bin and ask for sudo password. If you want to install the
	udev-rules use option --install-rules for they are not always required. 
	You can try without installing them first. You can do this later by
	giving the --rules-only option.

ENDHELP
}


# _install(<DEST>, <URL>, <INFOTEXT>)
_install() {
	echo "$3"
	$SUDO curl -Lfks -o "$1" "$2" && echo "[INFO] Success." || { echo "[EROR] Download failed."; XCODE=1; }
}

_install_udev() {
	if [ ! -d /etc/udev/rules.d/ ]; then
	    sudo mkdir -p /etc/udev/rules.d/
	fi

	local install=1

	if [ -f "$UDEV" ]; then
		echo "[WARN] Udev rules are already present, press ENTER to overwrite or x to skip"
		read -sn1 input 
		[ "$input" = "" ] &&  sudo rm "$UDEV" || install=0
	fi

	if [ $install -eq 1 ]; then

		echo "[INFO] Downloading udev list..."
		_install "$UDEV" "$BASEURL/udev.txt"

		echo "[INFO] Fix permissions"
		output=$(sudo chmod 644 $UDEV 2>&1) && echo "[ OK ] Fixed." || { echo "[EROR] $output"; XCODE=1; }

		echo "[INFO] Fix ownership"
		output=$(sudo chown root: $UDEV 2>&1) && echo "[ OK ] Fixed." || { echo "[EROR] $output"; XCODE=1; }

		sudo service udev restart 2>/dev/null >&2
		sudo killall adb 2>/dev/null >&2
	else
		echo "[INFO] Skip.."
	fi
}


echo
echo "[INFO] Nexus Tools $VERSION"
echo "[INFO] user space version"
echo "[INFO] Forked from https://github.com/corbindavenport/nexus-tools"
echo 

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

if [[ "$RULES" != "only" ]]; then
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
ADBURL="$BASEURL/bin/$ADBURL"
FBURL="$BASEURL/bin/$FBURL"
UDEVURL="$BASEURL/udev.txt"


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

[[ "$RULES" == "yes" || "$RULES" == "only" ]] && _install_udev
[[ "$RULES" == "only" ]] && { echo Done.; exit 0; }


echo "[INFO] Installing $ADB and $FASTBOOT"

# adb

if [ -f $ADB ]; then
    read -n1 -p "[WARN] ADB is already present, press ENTER to remove or x to cancel." input
	[ -z "$input" ] && $SUDO rm $ADB || exit 1
fi

_install "$ADB" "$ADBURL" "$ADBINFO"
	

# fastboot

if [ -f $FASTBOOT ]; then
    read -n1 -p "[WARN] Fastboot is already present, press ENTER to remove or x to cancel." input
    [ -z "$input" ] && $SUDO rm $FASTBOOT || exit 1
fi

_install "$FASTBOOT" "$FBURL" "$FBINFO"


echo "[INFO] Set ADB and Fastboot executable..."
output=$($SUDO chmod +x $ADB 2>&1) && echo "[INFO] OK" || { echo "[EROR] $output"; XCODE=1; }
output=$($SUDO chmod +x $FASTBOOT 2>&1) && echo "[INFO] OK" || { echo "[EROR] $output"; XCODE=1; }


if [ $XCODE -eq 0 ]; then
	echo "[ OK ] Done!"
	echo "[INFO] Type adb or fastboot to run."
    else
    	echo "[EROR] Install failed."
	echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
fi

echo " "
exit $XCODE
