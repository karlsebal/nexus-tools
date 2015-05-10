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

### TODO default to uninstall $HOME/bin only.

ADB=""
FASTBOOT=""
UDEV=""
SUDO=""
RULES="no"

XCODE=0

BASEURL="http://github.com/corbindavenport/nexus-tools/raw/master"
UPATH="/etc/udev/rules.d/51-android.rules"

OS=$(uname)
ARCH=$(uname -m)
KERN=$(uname -s)

VERSION="2.5-us"

_helptext() {
	cat <<-ENDHELP

	usage: $0 [--root] [--install-directory|-d <directory>] [--install-rules|-r]
			[--uninstall|-u [<directory>] ] [--uninstall-with-rules|U [<directory>] ]
	
	  -d, --install-directory <directory>		install into <directory>

	  -r, --install-rules				install udev-rules

	  -R, --rules-only				install udev-rules only

	  --root 					install in /usr/bin


	  --uninstall, -u [<directory>]			uninstall, leave udev rules

	  --uninstall-with-rules, -U [<directory>]	uninstall along with udev-rules

	
	${0##*/} defaults to install into <userhome>/bin if found, if not it will
	choose /usr/bin and ask for sudo password. If you want to install the
	udev-rules use option --install-rules for they are not always required. 
	You can try without installing them first and do this later by
	giving the --rules-only option.

	If uninstalling and no directory is given ${0##*/} will try to remove first
	in $HOME/bin and when neither adb nor fastboot is found there in /usr/bin.

ENDHELP
}


_get_sudo() {
	echo "[INFO] We need root access here."
	sudo echo "[ OK ] Sudo access granted." || { echo "[EROR] No sudo access."; exit 1; }
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
		
		[[ -z "$input" ]] && sudo rm "$UDEV" || install=0
	fi

	if [[ $install = 1 ]]; then
		_install "$UDEV" "$BASEURL/udev.txt" "[INFO] Downloading udev list..."

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

# removes adb and fastboot in $1
_remove() {
	if [[ -e "$1/adb" ]]; then
		echo [INFO] Removing "$1"/adb ..
		output=$($SUDO rm -v "$1/adb" 2>&1) && echo "[INFO] $output" || { echo [EROR] "$output"; XCODE=1; }
	else
		echo [INFO] "$1"/adb does not exist
	fi
	if [[ -e "$1/fastboot" ]]; then
		echo [INFO] Removing "$1"/fastboot ..
		output=$($SUDO rm -v "$1/fastboot" 2>&1) && echo "[INFO] $output" || { echo [EROR] "$output"; XCODE=1; }
	else
		echo [INFO] "$1"/fastboot does not exist
	fi
}

_remove_udev() {
	echo [INFO] Removing "$UDEV"
	output=$(sudo rm "$UDEV" 2>&1) && echo [ OK ] || { echo [EROR] "$output"; XCODE=1; }
}

# try remove in <HOME>/bin or /usr/bin
_try_remove() {
	# first try $HOME/bin
	[[ -e ${HOME%/}/bin/adb || -e ${HOME%/}/bin/fastboot ]] && { _remove "${HOME%/}/bin"; return; }

	echo "[INFO] No installation found in $HOME/bin. Choosing /usr/bin ."

	if [[ -e /usr/bin/adb || -e /usr/bin/fastboot ]]; then
		_get_sudo
		_remove /usr/bin
	else
		echo "[EROR] No installation found in /usr/bin."
		XCODE=1
	fi
}

_uninstall() {
	# if $1 is given but is no directory
	[[ -n $1 && ! -d $1 ]] && { echo "[ERROR] $1 is not a directory."; XCODE=1; return; } 
	# if $1 is given and not user writable or udev to uninstall
	[[ (! -w $1 && -n $1) || -n $UDEV ]] && _get_sudo
	# remove udev if requested
	[[ -n $UDEV ]] && _remove_udev
	# either remove adb/fastboot in $1 or try remove
	[[ -n $1 ]] && _remove $1 || _try_remove
}


echo
echo "[INFO] Nexus Tools $VERSION - user space version"
echo "[INFO] Forked from https://github.com/corbindavenport/nexus-tools"
echo 

## parse options ##

if [[ ("$@" =~ -d || "$@" =~ --install-directory) && "$@" =~ --root ]]; then
	echo "[EROR] you cannot use option --root along with -d"
	echo
	_helptext
	exit 1
fi

if [[ ("$@" =~ -R || "$@" =~ --rules-only) && $# -ne 1 ]]; then
	echo "[EROR] option -R|--rules-only does not apply with any other option"
	echo
	_helptext
	exit 1
fi

if [[ ("$@" =~ -u || "$@" =~ -U || "$@" =~ --uninstall || "$@" =~ --uninstall-with-rules) &&
	! ("$1" == "-u" || "$1" == "-U" || "$1" == "--uninstall" || "$1" == "--uninstall-with-rules") ]]; then
	
	echo -e "[EROR] Uninstall option must always be the first one.\n"
	exit 1
fi

until [ -z "$1" ]; do
	case "$1" in
		-h | --help)
			_helptext
			exit 0
			;;
		-r | --install-rules) 
			UDEV="$UPATH"
			RULES="yes"
			;;
		-R | --rules-only)
			UDEV="$UPATH"
			RULES="only"
			;;
		-d)
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
				fi
			done
			;;

		--root)
			ADB="/usr/bin/adb"
			FASTBOOT="/usr/bin/fastboot"
			;;

		--uninstall | -u)
			_uninstall "${2%/}"

			if [[ $XCODE -eq 0 ]]; then
				echo -e "[DONE] No errors.\n"
			else
				echo "[WARN] Errors during uninstall"
				echo -e "[DONE] Report bugs at http://github.com/karlsebal/nexus-tools\n"
			fi

			exit $XCODE
			;;

		--uninstall-with-rules | -U)
			UDEV="$UPATH"
			_uninstall "${2%/}"

			if [[ $XCODE -eq 0 ]]; then
				echo -e "[DONE] No errors.\n"
			else
				echo "[WARN] Errors during uninstall"
				echo -e "[DONE] Report bugs at http://github.com/karlsebal/nexus-tools\n"
			fi

			exit $XCODE
			;;
		*)
			echo -e "[WARN] Unknown option $1\n"
			exit 1
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
	echo "[INFO] ${ADB%/*} not user writable."
	echo "[INFO] Install as root"
	_get_sudo
fi


# install

[[ "$RULES" == "yes" || "$RULES" == "only" ]] && _install_udev
[[ "$RULES" == "only" ]] && { echo -e "Done.\n"; exit 0; }


echo "[INFO] Installing $ADB and $FASTBOOT"

# adb

if [ -f $ADB ]; then
    read -n1 -p "[WARN] ADB is already present, press ENTER to remove or x to cancel." input
	[ -z "$input" ] && $SUDO rm $ADB || { echo -e \n; exit 1; }
fi

_install "$ADB" "$ADBURL" "$ADBINFO"
	

# fastboot

if [ -f $FASTBOOT ]; then
    read -n1 -p "[WARN] Fastboot is already present, press ENTER to remove or x to cancel." input
    [ -z "$input" ] && $SUDO rm $FASTBOOT || { echo -e \n; exit 1; }
fi

_install "$FASTBOOT" "$FBURL" "$FBINFO"


echo "[INFO] Set ADB and Fastboot executable..."
output=$($SUDO chmod +x $ADB 2>&1) && echo "[INFO] ${ADB%/*} OK" || { echo "[EROR] $output"; XCODE=1; }
output=$($SUDO chmod +x $FASTBOOT 2>&1) && echo "[INFO] ${FASTBOOT%/*} OK" || { echo "[EROR] $output"; XCODE=1; }


if [ $XCODE -eq 0 ]; then
	echo "[ OK ] Done!"
	echo "[INFO] Type adb or fastboot to run."
    else
    	echo "[EROR] Install failed."
	echo "[EROR] Report bugs at: github.com/corbindavenport/nexus-tools/issues"
fi

echo " "
exit $XCODE
