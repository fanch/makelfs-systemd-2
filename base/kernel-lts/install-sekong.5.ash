#!/bin/bash
# Written by Thierry Nuttens
# Copyright Thierry Nuttens 2010-2011-2012-2013
# Installation script for the NuTyX system
# Ce script ne peut être utilisé que pour installer NuTyX

# *********************************************************************
# Variables Definition
# *********************************************************************
if [ -z "${version}" ]; then
	version='sekong.5'
fi
if [ -z "${URL}" ]; then
	URL='http://downloads.nutyx.org/'
fi
Homepage="${URL}"
ARCH=`uname -m`
Installbase="$version/$ARCH/release/"
Package=$Homepage$Installbase
Packagebase=$Installbase
if [ -z "${MountFolder}" ]; then
	MountFolder="/mnt/hd"
fi
if [ -f /tmp/swap.file ]; then
	SWAP=`cat /tmp/swap.file|cut -d " " -f1`
fi
Depot="/srv/www/htdocs/nutyx"
DepotPackages="$Depot/release"
DepotCD="/media/cdrom"
SetupFile="/tmp/firstsetup.sh"
# Size of the FullInstall in Mbytes
let LXDEInstall=1500
let XFCEInstall=1800
let GNOMEInstall=2600
let KDEInstall=3800
let BaseInstall=750

init=/sbin/init

# Number of seconds between STOPSIG and FALLBACK when stopping processes
KILLDELAY="3"

## Screen Dimensions
# Find current screen size

if [ -z "${COLUMNS}" ]; then
        COLUMNS=$(stty size)
        COLUMNS=${COLUMNS##* }
fi

# When using remote connections, such as a serial port, stty size returns 0
if [ "${COLUMNS}" = "0" ]; then
        COLUMNS=80
fi

## Measurements for positioning result messages
COL=$((${COLUMNS} - 8))
WCOL=$((${COL} - 2))

## Provide an echo that supports -e and -n
# If formatting is needed, $ECHO should be used
case "`echo -e -n test`" in
        -[en]*)
                ECHO=/bin/echo
                ;;
        *)
                ECHO=echo
                ;;
esac

## Set Cursor Position Commands, used via $ECHO
SET_COL="\\033[${COL}G"      # at the $COL char
SET_WCOL="\\033[${WCOL}G"    # at the $WCOL char
CURS_UP="\\033[1A\\033[0G"   # Up one line, at the 0'th char

## Set color commands, used via $ECHO
# Please consult `man console_codes for more information
# under the "ECMA-48 Set Graphics Rendition" section
#
# Warning: when switching from a 8bit to a 9bit font,
# the linux console will reinterpret the bold (1;) to
# the top 256 glyphs of the 9bit font.  This does
# not affect framebuffer consoles
NORMAL="\\033[0;39m"         # Standard console grey
SUCCESS="\\033[1;32m"        # Success is green
WARNING="\\033[1;33m"        # Warnings are yellow
FAILURE="\\033[1;31m"        # Failures are red
INFO="\\033[1;36m"           # Information is light cyan
BRACKET="\\033[1;34m"        # Brackets are blue

STRING_LENGTH="0"   # the length of the current message


# ******************************************************************************
# Functions
# ******************************************************************************

#*******************************************************************************
# Function - boot_mesg()
#
# Purpose:      Sending information from bootup scripts to the console
#
# Inputs:       $1 is the message
#               $2 is the colorcode for the console
#
# Outputs:      Standard Output
#
# Dependencies: - sed for parsing strings.
#               - grep for counting string length.
#
# Todo:
#*******************************************************************************
boot_mesg()
{
        local ECHOPARM=""

        while true
        do
                case "${1}" in
                        -n)
                                ECHOPARM=" -n "
                                shift 1
                                ;;
                        -*)
                                echo "Unknown Option: ${1}"
                                return 1
                                ;;
                        *)
                                break
                                ;;
                esac
        done

        ## Figure out the length of what is to be printed to be used
        ## for warning messages.
        STRING_LENGTH=$((${#1} + 1))

        # Print the message to the screen
        ${ECHO} ${ECHOPARM} -e "${2}${1}"

}

boot_mesg_flush()
{
        # Reset STRING_LENGTH for next message
        STRING_LENGTH="0"
}

boot_log()
{
        # Left in for backwards compatibility
        :
}

echo_ok()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${SUCCESS}  OK  ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}
echo_info()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${INFO} INFO ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

echo_failure()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${FAILURE} FAIL ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

echo_warning()
{
        ${ECHO} -n -e "${CURS_UP}${SET_COL}${BRACKET}[${WARNING} WARN ${BRACKET}]"
        ${ECHO} -e "${NORMAL}"
        boot_mesg_flush
}

print_error_msg()
{
        echo_failure
	ERREUR="yes"
        # $i is inherited by the rc script
        boot_mesg -n " FAILURE:\n\nVous ne devriez pas lire ce message d'erreur.\n\n" ${FAILURE}
        boot_mesg -n " Cela signifie qu'une erreur imprevue s'est produite"
        boot_mesg -n " lors de l'install de ${i} "
	boot_mesg -n " est sortie avec une valeur"
	boot_mesg -n " de sortie: ${error_value}.\n"
        boot_mesg_flush
        boot_mesg -n " Merci de bien vouloir nous informer"
        boot_mesg -n " via le site http://www.nutyx.org."
        boot_mesg " Merci de votre collaboration.\n"
        boot_mesg_flush
        boot_mesg -n "Pressez Enter pour continuer..." ${INFO}
        boot_mesg "" ${NORMAL}
        read ENTER
        end
		exit 1
}


#*******************************************************************************
# Function - log_success_msg "message"
#
# Purpose: Print a success message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_success_msg()
{
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${SUCCESS}""  OK
""${BRACKET}""]""${NORMAL}"
        return 0
}

#*******************************************************************************
# Function - log_failure_msg "message"
#
# Purpose: Print a failure message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_failure_msg() {
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${FAILURE}"" FAIL
""${BRACKET}""]""${NORMAL}"
        return 0
}

#*******************************************************************************
# Function - log_warning_msg "message"
#
# Purpose: print a warning message
#
# Inputs: $@ - Message
#
# Outputs: Text output to screen
#
# Dependencies: echo
#
# Todo: logging
#
#*******************************************************************************
log_warning_msg() {
        ${ECHO} -n -e "${BOOTMESG_PREFIX}${@}"
        ${ECHO} -e "${SET_COL}""${BRACKET}""[""${WARNING}"" WARN
""${BRACKET}""]""${NORMAL}"
        return 0
}
#*******************************************************************************
# Function - unmountall
#
# Purpose:	unmount all the mounted disks and partitions
#
# Inputs:	$1 the full path of the Distro
#
# Outputs:	Standard Output
#
# Dependencies: chroot
#
#*******************************************************************************
unmountall() {
# if [ $# -lt 1 ]; then 
#	echo 1>&2 
#	echo 1>&2 'Usage: unmountall point de montage (/arch par exemple)'
#	exit 1
# fi
if [ -d "$DepotCD/depot" ]; then
	umount ${1}/${Depot}
	umount  `cat /tmp/depot`
fi
umount ${1}/dev/shm
umount ${1}/dev/pts
umount ${1}/dev
umount ${1}/tmp 
umount ${1}/proc 
umount ${1}/sys
}
#*******************************************************************************
# Function - setup_chroot
#
# Purpose:	Enter the NuTyX Distribution
#
# Inputs:	$1 the full path of the Distro
#
# Outputs:	Standard Output
#
# Dependencies: chroot
#
#*******************************************************************************
setup_chroot() {
mount --bind /dev ${1}/dev
mount -t devpts devpts ${1}/dev/pts
mount -t proc proc ${1}/proc 
mount -t sysfs sysfs ${1}/sys
chroot ${1} /bin/bash -c "$SetupFile"
}
#*******************************************************************************
# Function - install_pkg()
#
# Purpose:      Install the selected package
#
# Inputs:       $1 is the package
#               $2 is the group
#		$3 Option to install, normally nothing except for grub
# Outputs:      Standard Output
#
# Dependencies: - wget
#               - boot_mesg
#               - pkgadd
# Todo:
#*******************************************************************************
install_pkg() {
	if $MountFolder/usr/bin/pkginfo -r $MountFolder -i| grep "^$1 " > /dev/null; then
		boot_mesg "$1 déjà installé sur $DEVICE..."
		echo_info
	else
		if  ! [ -d  "$DepotCD/depot" ]; then
      			packagefile=`cat PKGREPO|cut -d ':' -f 1|grep ^${1}#`
			packagefileToDownload=`echo $packagefile|sed 's/#/%23/'`
			boot_mesg "Téléchargement de $1..."
			wget $Homepage$Installbase${2}/$packagefileToDownload > /dev/null 2>&1
			echo_info
			mv $packagefileToDownload $packagefile  > /dev/null  2>&1
			# Installing the package
			boot_mesg "Installation de $1 sur $DEVICE..."
			$MountFolder/usr/bin/pkgadd -r $MountFolder $3 $1#* || print_error_msg
			echo_ok	
     		else
      			packagefile=`cat $DepotCD/depot/release/PKGREPO|cut -d ':' -f 1|grep ^${1}#`
			# Installing the package
			boot_mesg "Installation de $1 sur $DEVICE..."
			$MountFolder/usr/bin/pkgadd -r $MountFolder $3 $DepotCD/depot/release/$packagefile  || print_error_msg
			echo_ok	
		fi
	fi
}

#*******************************************************************************
# Function Check_DiskSpace
#
# Purpose:      Check the Available space after the using amont

# Inputs:       $1: Mount point
#	        $2: Amount in Kbytes going to be used
#
# Return:       status: 0 when ok
#	                1 not ok
# Todo:
#*******************************************************************************
Check_DiskSpace() {
	# df|grep "$1"|awk '{print $4}'
	let MinSize=$2+100
##	let Amoung=`df|grep "$1"|awk '{print $4}'`/1024
	let Amoung=`df|grep $MountFolder |awk '{print $(NF-2)}'`/1024
	let Amoung=$Amoung-$MinSize
	
	status="0"
	if [ $Amoung -lt 0 ]; then
		echo "Pas assez de place pour l'installation"
		echo_failure
		status="1"
	else
		echo "Espace restant après install: $Amoung Mbytes"
		echo_info
	fi
}

#*******************************************************************************
# Function DiskSpace
#
# Purpose:      Printout the Available space on the Mount point
#
# Inputs:       $1: Mount point
#
# Output:       Standard Output
#
# Todo:
#*******************************************************************************
DiskSpace() {
	let TotAmoung=`df|grep "$1"|awk '{print $4}'`/1024
	echo "Vous disposez actuellement de: ${TotAmoung} Mbytes sur le disque de destination"
}


error() {
echo "***********************************************"
echo ""
echo " $1"
echo ""
echo "***********************************************"
exit 1
}

end() {
if [ "$ERREUR" == "yes" ]; then
	if [ ! -f /tmp/depot ]; then
		rm -r ${MountFolder}/${Depot}
		boot_mesg "Suppression des paquets temporaires.."
		boot_mesg "Veuillez corrigez et relancer"
	fi
fi
cd ~
unmountall $MountFolder > /dev/null 2>&1

if [ "$MIG" == "0" ]; then
  umount $MountFolder > /dev/null 2>&1
fi
if [ "$SWAP" != "" ]; then
 swapoff $SWAP
fi
}
#****************************************************************************
# Function expect
# 
# Purpose:	Check that the answer is nothing else then the supply
#		arguments
# Inputs:	$1: answer 1
#		$2: answer 2
#		$3: The question to ask
#
# Output:	Standard Output
#
#****************************************************************************
expect(){
# echo -n "$3"
# read answer
while [ "$answer" != "o" ] && [ "$answer" != "n" ]; do
	echo -n "$3"
	read answer
done
}
#****************************************************************************
# Function find_usb
#
# Purpose: Check if there is a usb key in the drive, if yes check if it
# is nutyxcd, if yes mount it
# Inputs:
#
# Output: /tmp/depot
#
#****************************************************************************
find_usb() {
#skip=16384 for fat16
#skip=1144 for ext2
#skip=65636 for reiserfs
EXPECT_LABEL="NuTyX-usb"
for SYS in /dev/sd?? ; do
	#if [ ! -d "$SYS" ]; then  continue; fi
	DEV=/dev/${SYS##*/}
	# en reiserfs
	LABEL=`dd if=$DEV bs=1 skip=65636 count=9 2>/dev/null`
	if [ $LABEL == $EXPECT_LABEL ]  2>/dev/null ; then
		ln -s $DEV /dev/nutyx-usb
		break
	fi
	# en ext2/3/4
        LABEL=`dd if=$DEV bs=1 skip=1144 count=9 2>/dev/null`
        if [ $LABEL == $EXPECT_LABEL ]  2>/dev/null ; then
                ln -s $DEV /dev/nutyx-usb
                break
        fi
	# en fat16
        LABEL=`dd if=$DEV bs=1 skip=16384 count=9 2>/dev/null`
        if [ $LABEL == $EXPECT_LABEL ]  2>/dev/null ; then
                ln -s $DEV /dev/nutyx-usb
                break
        fi
done
if [ -b /dev/nutyx-usb ]; then
	mkdir -p /media/cdrom 2>/dev/null
	mount -n /dev/nutyx-usb /media/cdrom
	if [ -d /media/cdrom/depot ]; then
		echo $DEV > /tmp/depot
	else
		umount -n /media/cdrom
	fi
fi
}
#****************************************************************************
# Function find_cd
#
# Purpose: Check if there is a CD/DVD in the drive, if yes check if it
# is nutyxcd, if yes mount it
# Inputs:
#
# Output: /tmp/depot
#
#****************************************************************************
find_cd() {
EXPECT_LABEL="nutyxcd"
for SYS in /sys/block/sd* /sys/block/sr* ; do
        if [ ! -d "$SYS" ]; then  continue; fi
        DEV=/dev/${SYS##*/}
        LABEL=`dd if=$DEV bs=1 skip=32808 count=32 2>/dev/null`
        if [ $LABEL == $EXPECT_LABEL ]  2>/dev/null ; then
                ln -s $DEV /dev/nutyx-cd
                break
        fi
done
if [ -b /dev/nutyx-cd ]; then
	mkdir -p /media/cdrom 2>/dev/null
        mount -n /dev/nutyx-cd /media/cdrom
        if [ -d /media/cdrom/depot ]; then
                echo $DEV > /tmp/depot
        else
                umount -n /media/cdrom
        fi
fi
}
#****************************************************************************
# Function getdirectdeps
#
# Purpose: list alls the directs dependencies
# Input: Name of package
#
# Output: array
#****************************************************************************
getdirectdeps() {
local pkgdir=${MountFolder}${Depot}/release
local pkgname="$1"
local ddep
local dep
if ! [ -f "$pkgdir/PKGDEPS" ]; then
        error "$pkgdir/PKGDEPS pas trouvé"
fi
dep=`grep ^"$1 " $pkgdir/PKGDEPS|cut -d ":" -f2|sed "s/,/ /g"`
#dep=${ddep[0]}
if [ -n "${dep}" ]; then
        echo "${dep}"
fi
}
#****************************************************************************
# Function getdependencies
#
# Purpose: list alls the dependencies
# Input: Name of package
#
# Output: printout of deps (one per line)
#****************************************************************************
getdependencies() {
local pkgname="$1"
local pkgparent="$2"
if [ "$pkgparent" == "" ]; then
	depstring="$1"
fi
if ! [ "`getdirectdeps $pkgname`" == "" ]; then
        for i in `getdirectdeps $pkgname`
	do
		if ! ( echo $depstring|grep " ${i} " > /dev/null ); then
			depstring="$i $depstring"
			getdependencies $i $pkgname
		fi
        done
else
        if [ "$pkgparent" == "" ]; then
                echo "$pkgname n'a pas de deps"
                return 0
        fi
fi
}

checkLOCALE()
{
while [ "$clavier" != "fr_CH-latin1" ] \
&& [ "$clavier" != "azerty" ] \
&& [ "$clavier" != "fr_CH" ] \
&& [ "$clavier" != "fr" ] \
&& [ "$clavier" != "fr-latin1" ] \
&& [ "$clavier" != "fr-latin9" ] \
&& [ "$clavier" != "be-latin1" ] \
&& [ "$clavier" != "cf" ] \
&& [ "$clavier" != "us" ]; do
	echo "Le clavier n'est pas encore supporté."
	echo "Relancez le script en passant votre clavier via la variable KEYMAP"
	echo "Exemple: KEYMAP=hu bash install-$version.ash /dev/sda1 reiserfs"
	echo "ou"
	echo -n "choisissez votre clavier azerty, fr_CH-latin1, fr_CH, fr, fr-latin1, fr-latin9, be-latin1, cf ou us: "
	read answer
	clavier="$answer"
done

}
#****************************************************************************
# Function getPKGREPO
# 
# Purpose:	Get the list of the available package in selected 
#		directory
# Inputs:	$1: The selected directory
#
# Output:	Standard Output
#
#****************************************************************************

getPKGREPO()
{
cd ${MountFolder}${DepotPackages}
if ! [ -d $1 ]; then
	mkdir $1
fi
for i in PKGREPO PKGDEPS PKGINST PKGREAD PKGGRP index.html
  do wget $Package$1/$i -O $i > /dev/null 2>&1
done
}
install_base()
{
# pkg-get.conf
cat  > ${MountFolder}/etc/pkg-get.conf << "EOF"
###
# /etc/pkg-get.conf
#
# pkg-get configuration file
# Dépot des paquets NuTyX
# Par défault, seul le dépot "release" est activé.
EOF
echo "pkgdir ${Depot}/release|$Homepage$version/$ARCH/release" >>  ${MountFolder}/etc/pkg-get.conf
cat >>  ${MountFolder}/etc/pkg-get.conf << "EOF"
# Liste de paquets constituant une NuTyX de base
EOF
for i in aaabasicfs glibc tzdata \
	zlib binutils gmp mpfr mpc gcc sed \
	ncurses util-linux e2fsprogs coreutils iana-etc m4 \
	bison autoconf automake diffutils bc \
	procps grep readline bash pam \
	libtool gdbm inetutils perl ca-certificates \
	bzip2 file gawk findutils flex gettext \
	groff gzip iproute2 kbd less libpipeline make\
	man-db kmod patch psmisc shadow sysklogd sysvinit \
	tar texinfo udev vim pkgutils pkgmk prt-get dhcpcd xfsprogs \
	wget xz libarchive openssl pkg-config libffi python libgl sudo \
	rsync ports net-tools pkg-get cpio reiserfsprogs libtirpc grub
	
	do 
		if [ "$i" == "aaabasicfs" ]; then
			echo -n "base: aaabasicfs," >>  ${MountFolder}/etc/pkg-get.conf
		else
			echo -n "$i," >>  ${MountFolder}/etc/pkg-get.conf
		fi
		install_pkg "$i"
done
###
df "$MountFolder" | grep mapper >/dev/null
if [ $? -eq 0 ]; then
        for i in lvm2
                do install_pkg "$i"
        done
fi
###
}
# *****************************************************************************************************
# Begin of Installer
# *****************************************************************************************************

# Checking if we use the right interpreter
if ! (bash --version >/dev/null 2>&1)  then
	if  ! (which busybox > /dev/null 2>&1) then
		error " Mauvais interpreteur, veuillez installer et utiliser bash"
	fi
fi
# Checking if we have ldconfig
# if ! (ls /sbin/ldconfig >/dev/null 2>&1) then
#	touch /sbin/ldconfig
#	chmod 755 /sbin/ldconfig
# fi
# Checking the type of install

MIG=`echo $1|cut -d "/" -f 2`
# echo $MIG
if [ "$MIG" == "dev" ]; then
	MIG=0
else
	MountFolder=$1
	MIG=1
	echo "Cette installation est une migration sur $1"
	echo_info
fi
DEVICE=$1

# Welcome

echo "***********************************************"
if [ "$MIG" == "0" ]; then
	if [ ! -z "${KEYMAP}" ] || [ -f /etc/sysconfig/console ]; then
		if [ $# -lt 2 ]; then
			echo "* Vous n'avez pas spécifié assez d'arguments  *"
			echo "* Argument 1: la partition de destination     *"
			echo "* Argument 2: le système de fichiers          *"
			echo "*                                             *"	
			echo "* Merci de bien vouloir relancer la commande  *"
			echo "* avec les bons arguments                     *"
			echo "***********************************************"
			echo ""
			echo "exemple: install-$version.ash /dev/sda1 ext3"

			exit 1
		fi
		if [ ! -z "${KEYMAP}" ]; then
			clavier=$KEYMAP
		else
			clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
		fi
	else
		if [ $# -lt 3 ]; then
			echo "* Vous n'avez pas specifié assez d'arguments  *"
			echo "* Argument 1: la partition de destination     *"
			echo "* Argument 2: le système de fichiers          *"
			echo "* Argument 3: la disposition du clavier       *"
			echo "*                                             *"
			echo "* Merci de bien vouloir relancer la commande  *"
			echo "* avec les bons arguments                     *"	
			echo "***********************************************"
			echo ""
			echo "exemple: install-$version.ash /dev/hda1 ext4 fr-latin1"
			exit 1
		fi
		clavier=$3
		checkLOCALE
	fi
	echo "Le système de fichier sera $2"
	echo_info
	FILESYSTEM=$2
else
	FILESYSTEM=`grep " / " /etc/fstab|awk '{ print $3 }' `
	if [ ! -z "${KEYMAP}" ] || [ -f /etc/sysconfig/console ]; then
		clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
		if [ $# -lt 1 ]; then
                        echo "* Vous n'avez pas spécifié assez d'arguments  *"
                        echo "* Argument 1: le dossier de destination       *"
                        echo "*                                             *"
                        echo "* Merci de bien vouloir relancer la commande  *"
                        echo "* avec les bons arguments                     *"
                        echo "***********************************************"
                        echo ""
			echo "exemple: install-$version.ash /test"
                        exit 1
		fi
		if [ ! -z "${KEYMAP}" ]; then
                        clavier=$KEYMAP
                else
                        clavier=`grep "^KEYMAP" /etc/sysconfig/console|sed 's/KEYMAP=//'|sed 's/.map//'`
                fi
	else
                if [ $# -lt 2 ]; then
                        echo "* Vous n'avez pas spécifié assez d'arguments  *"
                        echo "* Argument 1: le dossier de destination       *"
                        echo "* Argument 2: la disposition du clavier       *"
                        echo "*                                             *"
                        echo "* Merci de bien vouloir relancer la commande  *"
                        echo "* avec les bons arguments                     *"
                        echo "***********************************************"
                        echo ""
                        echo "exemple: install-$version.ash /test fr-latin1"
                        exit 1
		fi
		clavier=$2
		checkLOCALE
	fi	
fi
if [ -z "${KERNEL}" ]; then
	if ! (which dialog > /dev/null 2>&1) then
		echo "Le script d'installation peut désormais utiliser dialog"
		echo "pour pouvoir faire une installation personnalisée."
		echo "Si vous souhaitez profiter de cette fonctionnalitée,"
		echo "veuillez installer l'application dialog"
		echo ""
		echo "Par ailleurs vous avez choisi de compilez votre propre kernel"
		echo ""
		echo -n "Souhaitez-vous continuer sans dialog et sans kernel ? Tapez o pour continuer "
		read answer
		if ! [ "$answer" == "o" ]; then 
			echo 'Veuillez taper la lettre minuscule "o" si vous souhaitez continuer sans kernel'
			exit 1
		fi
	fi
fi
echo $clavier > /tmp/locale.check
CLAVIER=$clavier

# Recherche d'un dépot sur clé USB
if ! [ -f /tmp/depot ]; then
        find_usb
fi
# Recherche d'un dépot sur CD
if ! [ -f /tmp/depot ]; then
	find_cd
fi

# Checking the MountFolder
if ! [ -d $MountFolder ]; then
	mkdir -p $MountFolder
fi
# Checking the Mount point
if [ "$MIG" == "0" ]; then
	# Checking the device exist ?
	if ! [ -b  $1 ]; then
		error "Point de montage  $1 inexistant"
		exit 0
	fi
	# Mounting the System files
	if ! mountpoint /$MountFolder > /dev/null; then
		mount -t $FILESYSTEM $1 $MountFolder || error "Partition invalide ou Formatage incorrect"
	fi
	# Check available space
	Check_DiskSpace $1 $BaseInstall
	if [ $status == "1" ]; then
		DiskSpace $1 
		echo "L'installation nécessite $BaseInstall Mbytes minimum"
		end
		exit 1
	fi
	
fi
# Création du dossier des dépots
if ! [ -d ${MountFolder}${DepotPackages} ]; then
	mkdir -p ${MountFolder}${DepotPackages}

fi
# echo "Checking It's the depot is available."
if [ -f "$DepotCD/depot/release" ]; then
	mount -t squashfs $DepotCD/depot/release ${MountFolder}${DepotPackages}
fi
if [ -d "$DepotCD/depot/release" ]; then
	mount --bind $DepotCD/depot/release ${MountFolder}${DepotPackages}
fi
# Téléchargement des fichiers PKG*
cd ${MountFolder}${DepotPackages}
if ! [ -d "$DepotCD/depot" ]; then
	getPKGREPO
else
	KERNEL_FILE=`find ${MountFolder}${DepotPackages} -name "kernel*"|cut -d "#" -f1`
	KERNEL=`basename $KERNEL_FILE`
fi
if [ -z "${KERNEL}" ]; then
	if (which dialog > /dev/null 2>&1) then
		rm /tmp/choix_KERNEL > /dev/null 2>&1
		cat > /tmp/choix_KERNEL << "EOF"
 --title " Choisissez votre kernel " \
 --ok-label " Suivant " --no-cancel \
 --radiolist " Choisissez le kernel adapté à votre matériel parmi la liste " 0 0 0 \
EOF
		for i in `cat ${MountFolder}${Depot}/release/PKGREPO|grep ^kernel|cut -d ":" -f1|cut -d "#" -f1`
		do
		echo "\"`grep ^$i# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f1|sed "s/.pkg.tar.xz//"|sed "s/#/ /"`\" \"`grep ^$i# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f 4`\" off"
		done >> /tmp/choix_KERNEL
		dialog --file /tmp/choix_KERNEL  2>/tmp/kernel_choisi
		KERNEL=`cat /tmp/kernel_choisi|cut -d " " -f1`
	fi
fi
if ! [ -z "${KERNEL}" ]; then
	if ! ( grep ${KERNEL} ${MountFolder}${Depot}/release/PKGREPO > /dev/null 2>&1) then
		ERREUR="yes"
		end
		error "Le kernel: ${KERNEL} n'existe pas en binaire"
	fi
else
	if (which dialog > /dev/null 2>&1) then
 		dialog --title " !!! Aucun kernel choisi !!!! " \
        	--msgbox " Vous avez choisi d'installer le kernel après l'installation de base. N'oubliez pas de le faire ...  " 7 65
	fi
fi

if (which dialog > /dev/null 2>&1) && [ -z "${PAQUETS}" ]; then
	if [ -f "${MountFolder}${Depot}/release/PKGGRP" ] && [ ! -d "$DepotCD/depot/release" ]; then
                cat > /tmp/choix_WM << "EOF"
--title " Souhaitez-vous une interface graphique ? " \
--colors --ok-label " Suivant " --no-cancel \
--radiolist " Si oui, choisissez une interface graphique parmi la liste,
sinon pressez simplement < \Z1S\Znuivant > pour installer la base uniquement " 0 0 0 \
EOF
                for i in `cat ${MountFolder}${Depot}/release/PKGGRP|grep ^Interface|cut -d ":" -f2|sed "s/,/ /g"`
                do
                        echo "\"`grep ^$i# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f1|sed "s/.pkg.tar.xz//"|sed "s/#/ /"`\" \
                        \"`grep ^$i# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f 4`\" off"
                done >> /tmp/choix_WM
                dialog --file /tmp/choix_WM  2>/tmp/wm_choisi
                WM=`cat /tmp/wm_choisi|cut -d " " -f1`
                if [ ! -z "${WM}" ]; then
			CHOIX_WM=$WM
                        if ! (echo $WM|grep xorg>/dev/null); then WM="xorg $WM";fi
                        sed "/^Interface/d" ${MountFolder}${Depot}/release/PKGGRP > /tmp/PKGGRP
                        echo ""
                        for  i in `echo ${WM}`
                                do echo "Recherche des dépendances de ${i}, veuillez patienter ..."
                                echo_info
				getdependencies $i
                                for j in `echo $depstring`
                                        do sed -i "s/,$j,/,/" /tmp/PKGGRP
					   sed -i "s/:$j,/:/" /tmp/PKGGRP
                                done
                        done
                        if (echo $WM|grep kde3 >/dev/null); then sed -i "/^kde/d" /tmp/PKGGRP;fi
                        echo "Production de la liste des paquets disponibles pour ${CHOIX_WM}, veuillez (encore) patienter ..."
			echo_info
			sed -i "s/^${CHOIX_WM}/${CHOIX_WM}-extra/" /tmp/PKGGRP
                        for i in `cat /tmp/PKGGRP|cut -d ":" -f1`
                                do
                                        j="`cat /tmp/PKGGRP|grep ^$i|cut -d ":" -f3`"
                                        echo "--title \" $i \" \\" > /tmp/choix_$i
                                        echo "--ok-label \" Retour \" \\" >> /tmp/choix_$i
					echo "--no-cancel \\" >> /tmp/choix_$i
                                        echo "--checklist \" $j \" 0 0 0 \\" >> /tmp/choix_$i
                                        for j in `cat /tmp/PKGGRP|grep ^$i|cut -d ":" -f2|sed "s/,/ /g"`
                                                do
                                                        echo -n "."
                                                        echo \
"\"$j `grep ^$j# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f 1|cut -d "#" -f2|sed "s/.pkg.tar.xz//"`\" \"`grep ^$j# ${MountFolder}${Depot}/release/PKGREPO|cut -d ":" -f 4|sed 's/\"//g'|sed 's|\\\||g'`\" off"  >> /tmp/choix_$i
                                                done
                                done
                        echo "--title \" Choix d'applications supplémentaires \" \\" > /tmp/text_MAIN
                        echo "--menu \" Vous avez choisis d'installer \Z1$CHOIX_WM\Zn, si \
vous le souhaitez, vous pouvez installer des applications supplémentaires provenant des groupes ci-dessous. \
Une fois votre choix termniné, pressez < \Z1S\Znuivant > pour procéder à l'installation de \Z1$CHOIX_WM\Zn et ses dépendances \
ainsi que de toutes les applications que vous avez selectionnez ci-dessous.\" 0 0 0 \\" >> /tmp/text_MAIN
                        for i in `cat /tmp/PKGGRP|cut -d ":" -f1`
                                do echo "" > /tmp/paquets_choisis_$i
                        done
                        cat > /tmp/setup_main << "EOF"
#!/bin/bash
update(){
OLD_IFS=$IFS
IFS="|"
sed -i "s/\" \"/\"|\"/g" $1
choix=(`cat $1`)
i=0
while [ -n "${choix[i]}" ]; do
                K[i]=`grep ${choix[i]} $2`
                J[i]=`grep ${choix[i]} $2|sed "s/off$/on/"`
                sed -i "s/${K[i]}/${J[i]}/" $2
                i=$((i+1))
done
}
while [ true ];
do
dialog --ok-label " Choisir " --cancel-label " Suivant " --colors --file /tmp/text_MAIN 2>/tmp/choix
retval=$?
choice=`cat /tmp/choix`
case $retval in
0|2)
        case $choice in
EOF
                        for i in `cat /tmp/PKGGRP|cut -d ":" -f1`
                        do
                                echo "\"$i\" \"`cat /tmp/PKGGRP|grep ^$i|cut -d ":" -f3`\"" >> /tmp/text_MAIN
                                echo "$i)" >>  /tmp/setup_main
                                echo "    cp /tmp/choix{_$i,}" >>  /tmp/setup_main
                                echo "    update /tmp/paquets_choisis_$i /tmp/choix" >>  /tmp/setup_main
                                echo "    dialog --file /tmp/choix 2>/tmp/paquets_choisis" >>  /tmp/setup_main
				echo "    if [ ! \"\`cat /tmp/paquets_choisis\`\" == \"\" ]; then" >>  /tmp/setup_main
				echo "        cp /tmp/paquets_choisis{,_$i}" >>  /tmp/setup_main
				echo "    fi;;" >>  /tmp/setup_main
                        done
                        cat >> /tmp/setup_main << "EOF"
        esac;;

1)
        break;;
255)
        break;;
esac
done
IFS=$OLD_IFS
EOF
                        bash /tmp/setup_main
                        # Supprimer les guillemets et la version du paquet
                        for i in `cat /tmp/PKGGRP|cut -d ":" -f1`
                        do
                                sed -i 's/"\([^ ]\+\) [^"]\+"/\1/g' /tmp/paquets_choisis_$i
                                PAQUETS="$PAQUETS `cat /tmp/paquets_choisis_$i`"
                        done
                        PAQUETS="$WM $PAQUETS"
		fi
	fi
fi
echo_ok
echo "Installation de var/lib/pkg ..."
mkdir -p $MountFolder/var/lib/pkg > /dev/null 2>&1 || print_error_msg
echo_ok

echo "Création de la db..."
touch $MountFolder/var/lib/pkg/db > /dev/null 2>&1 || print_error_msg
echo_ok
pkgconf="fail"
error_value=101
if [ ! -f  /usr/bin/pkg-get ] || [ ! -f /usr/bin/pkgadd ] || [ ! -f /etc/pkg-get.conf ] || [ $pkgconf != "OK" ]; then
	# Getting pkgutils and pkg-get

	packagefile=`cat PKGREPO\
	|cut -d ':' -f 1| grep pkgutils#|sed 's/#/%23/'`
	package=`echo $packagefile|cut -d '%' -f1`

	if  [ ! -f $package* ]; then
		echo "Téléchargement de pkgutils.."
		wget $Homepage$Packagebase$packagefile >/dev/null 2>&1 || print_error_msg
		if [ -f pkgutils*%23* ]; then  
			mv $packagefile `echo $packagefile|sed "s/%23/#/"`
		fi
		echo_ok
	fi
	# Extracting pkgutils package
	echo "Extraction de pkgutils ..."
	if   (which busybox > /dev/null 2>&1) then
		xz -c -d pkgutils*|tar -C $MountFolder -xf - || print_error_msg
	else
		tar -C $MountFolder -xf pkgutils* || print_error_msg
	fi
	echo_ok

	# Installing pkgutils again

	echo "Installation de pkgutils ..."
	if $MountFolder/usr/bin/pkginfo -r $MountFolder -i |grep pkgutils > /dev/null; then
		echo "pkgutils déjà installé..."
		echo_info
	else
		$MountFolder/usr/bin/pkgadd -r $MountFolder -f pkgutils* || print_error_msg
		echo_ok
	fi
	install_base
else
	/usr/bin/pkg-get base ${MountFolder}
fi
# Need to update rsync config files
cat > ${MountFolder}/etc/ports/base.rsync << "EOF"
host=downloads.nutyx.org/nutyx
collection=ports/sekong/base/
destination=/usr/ports/base
EOF
cat > ${MountFolder}/etc/ports/extra.rsync << "EOF"
host=downloads.nutyx.org/nutyx
collection=ports/sekong/extra/
destination=/usr/ports/extra
EOF

echo "#!/bin/sh" > ${MountFolder}${SetupFile}
echo "export ARCH=$ARCH" >> ${MountFolder}${SetupFile}
echo "export Homepage=$Homepage" >> ${MountFolder}${SetupFile}
echo "export DepotCD=$DepotCD" >> ${MountFolder}${SetupFile}
echo "export version=$version" >> ${MountFolder}${SetupFile}
echo "export CLAVIER=$CLAVIER" >> ${MountFolder}${SetupFile}
if  ! [ -z "${KERNEL}" ]; then
	echo "export KERNEL=$KERNEL" >> ${MountFolder}${SetupFile}
fi
cat >> ${MountFolder}${SetupFile} << "EOF"
/usr/sbin/pwconv
/usr/sbin/grpconv
/bin/chmod 1777 /tmp
source /etc/profile
touch /var/lib/pkg/pkg-get.locker
touch /var/lib/pkg/prt-get.locker
EOF
if ! [ -z "${KERNEL}" ]; then
	echo '/usr/bin/pkg-get install $KERNEL' >> ${MountFolder}${SetupFile}
fi
if ! [ -z "${PAQUETS}" ]; then
	echo "pkg-get depinst $PAQUETS" >> ${MountFolder}${SetupFile}
	cat >> ${MountFolder}${SetupFile} << "EOF"
EOF
fi
cat >> ${MountFolder}${SetupFile} << "EOF"
clear
echo "************************************************************"
echo ""
echo " Vous êtes maintenant dans la nutyx $version"
echo ""
echo "***********************************************************"
/bin/passwd
clear
echo "***********************************************************"
echo ""
echo " Vous êtes TOUJOURS dans la nutyx $version."
EOF
if [ -z "${PAQUETS}" ] && [ ! -f /tmp/depot ]; then
	cat >> ${MountFolder}${SetupFile} << "EOF"	
clear
ports -u
echo "***********************************************************"
echo ""
echo " Vous êtes TOUJOURS dans la nutyx $version."
echo ""
echo " Vous pouvez compiler ou installer une interface graphique."
echo ""
echo " Pour compiler xfce4, gnome ou kde:"
echo ""
echo " Exemple pour xfce4"
echo " prt-get depinst xfce4"
echo ""
echo " Si vous souhaitez installer directement, remplacez"
echo " la commande prt-get par pkg-get."
echo ""
echo " pkg-get depinst xfce4"
echo ""
echo " Si vous installez via le wifi, veuillez installer "
echo " wpa_supplicant et wireless_tools"
echo ""
echo " pkg-get depinst wpa_supplicant wireless_tools"
echo ""
echo " Aucun utilisateur n'a été créé"
EOF
fi
if [ -z "${KERNEL}" ]; then
	cat >> ${MountFolder}${SetupFile} << "EOF"
echo ""
echo " !!! AUCUN KERNEL installé !!! "
echo ""
echo " Installez ou Compilez un kernel "
echo " si vous souhaitez amorcer votre NuTyX "
echo ""
echo " Vous êtes perdu, le manuel de nutyx est à votre disposition:"
echo ""
echo " man nutyx "
echo ""
echo " Pour sortir de la nutyx $version, tapez:"
echo ""
echo " exit"
echo ""
su -
EOF
fi
if ! [ -z "${PAQUETS}" ]; then
	cat >> ${MountFolder}${SetupFile} << "EOF"

echo ""
echo " Veuillez créer un nouvel utilisateur: "
echo ""
/usr/bin/nu
EOF
fi
if  ! (which busybox > /dev/null 2>&1); then
	if ! [ -z "${KERNEL}" ]; then
		echo "su -" >> ${MountFolder}${SetupFile}
	fi
fi
if [ "${KEYMAP}" != "False" ] && [ "${KEYMAP}" != "false" ]; then
	echo "KEYMAP=${CLAVIER}.map" >>  ${MountFolder}/etc/sysconfig/console
fi

# ifconfig.*
found=""
for i in /etc/sysconfig/ifconfig.* /etc/sysconfig/network /etc/wpa_supplicant.conf.*
do 
	if [ -f $i ];then
		cp $i ${MountFolder}/$i
		found="OK"
	fi
done
for i in /etc/wpa_supplicant.conf.*
do 
        if [ -f $i ];then
		cp $i  ${MountFolder}/$i
	fi
done
# If nothing found guessing dhcpcd on eth0
if [ "$found" == "" ]; then
	cat > ${MountFolder}/etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT="yes"
SERVICE="dhcpcd"
DHCP_START=""
DHCP_STOP="-k "
# Mettez PRINTIP="yes" pour que le script affiche l'addresse IP
PRINTIP="no"
# Mettez PRINTALL="yes" pour que le script affiche tous le détails
# de la connection réseau
PRINTALL="no"
EOF
fi
if [ ! -f ${MountFolder}/etc/sysconfig/network ];then 
	cat > ${MountFolder}/etc/sysconfig/network << "EOF"
HOSTNAME='nutyx'        # Le nom de votre machine
MANAGER=''              # Le gestionnaire de réseau (wicd/networkmanager/cli/rien)
NETWORKWAIT='no'        # Attendre ou non le réseau
LINKDELAY='15'          # Délai d'initialisation de Networkmanager
NETWORKDELAY='0'        # Délai d'attente après l'initialisation de Networkmanager pour les montage nfs par exemple
EOF
fi
# Config X11
mkdir -p ${MountFolder}/etc/X11/xorg.conf.d/
cat > ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf << "EOF"
Section "InputClass"
	Identifier      "Generic Keyboard"
	Driver          "evdev"
	Option          "CoreKeyboard"
	Option          "XkbRules"      "xorg"
	Option          "XkbModel"      "pc105"
EOF
if [ "${KEYMAP}" != "False" ] && [ "${KEYMAP}" != "false" ]; then
	case $CLAVIER in
	us)
                echo "export LANG=en_US.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
                echo '  Option  "XkbLayout"     "us"' >> \
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
        ;;
        be-latin1|wangbe*)
                echo "export LANG=fr_BE.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
                echo '	Option	"XkbLayout"	"be"' >> \
		${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                ln -sf /usr/share/zoneinfo/Europe/Brussels ${MountFolder}/etc/localtime
        ;;
        cf)
                echo "export LANG=fr_CA.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
                echo '    Option      "XkbLayout"  "ca"' >>\
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                ln -sf /usr/share/zoneinfo/Canada/Eastern ${MountFolder}/etc/localtime
        ;;
        fr|fr-*|azerty)
                echo "export LANG=fr_FR.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
                echo '	Option	"XkbLayout"	"fr"' >> \
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                ln -sf /usr/share/zoneinfo/Europe/Paris \
                ${MountFolder}/etc/localtime
        ;;
        fr_CH*)
                echo "export LANG=fr_CH.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
                ln -sf /usr/share/zoneinfo/Europe/Zurich \
                ${MountFolder}/etc/localtime
                echo '	Option	"XkbLayout"	"ch"' >> \
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                echo '	Option	"Xkbrules"	"xorg"' >> \
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                echo '	Option	"XkbVariant"	"fr"'  >>\
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                ;;
        *)
		echo "export LANG=fr_FR.utf8" > ${MountFolder}/etc/profile.d/i18n.sh
		echo '# Ajustez le clavier ci-dessous'  >>\
		${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
                echo '	Option	"XkbLayout"	"us"' >>\
                ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf

                ;;

	esac
echo '  Option "XkbOptions" "grp:alt_shift_toggle"' >>\
${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
echo "EndSection" >> ${MountFolder}/etc/X11/xorg.conf.d/20-keyboard.conf
fi

if [ "${KEYMAP}" != "False" ]; then
	echo "$1     /    $2    defaults   0   1" >> ${MountFolder}/etc/fstab  
fi
if [ "${KEYMAP}" != "False" ]; then
	if [ -f /tmp/swap.file ]; then
		echo "`cat /tmp/swap.file|cut -d " " -f 1`     swap      swap   pri=1   1  1" >> ${MountFolder}/etc/fstab
	fi
fi
chmod 755 ${MountFolder}${SetupFile}
if [ -f /etc/resolv.conf ]; then
	cp /etc/resolv.conf ${MountFolder}/etc
fi
if [ -f /etc/sysconfig/clock ]; then
	cp /etc/sysconfig/clock \
	${MountFolder}/etc/sysconfig/clock
fi
if [ "$MIG" == "1" ] && [ "${KEYMAP}" != "False" ] && [ "${KEYMAP}" != "false" ]; then
	for i in hosts hosts.allow hosts.deny exports fstab
	do
		if [ -f /etc/$i ]; then
			cp -a /etc/$i ${MountFolder}/etc/
		fi
	done
fi
cd /
# Entering chroot
setup_chroot $MountFolder
# Copy the log install
if [ -f /var/log/install.log ]; then
	cp /var/log/install.log \
	${MountFolder}/var/log/pkg-get.log
fi
# Exit and unmounting all
end
if [ "$MIG" == "0" ]; then
	if [ -f /tmp/depot ]; then
		umount  ${MountFolder}${DepotPackages} > /dev/null 2>&1
		umount  ${MountFolder}${DepotCD} > /dev/null 2>&1
		if ! (which dialog > /dev/null 2>&1)  then
echo "******************************************************"
echo "* Installation terminée. Merci d'avoir choisie nutyx *"
echo "* Si votre connection  internet le permet,           *"
echo "* pour plus d'info, venez nous rendre visite sur:    *"
echo "*                                                    *"
echo "*                http://www.nutyx.org                *"
echo "*                                                    *"
echo "******************************************************"
echo ""
		else
			dialog --title " Installation terminée " \
			--msgbox "Merci d'avoir choisie nutyx. \
Si votre connection internet le permet, \
pour plus d'info, venez nous rendre visite sur:\n\n\
http://www.nutyx.org\n\n\
Pensez à retirer le LiveCD ou la clé USB \
avant de redémarrer la machine" 0 0

		fi
		umount /media/cdrom > /dev/null 2>&1
		eject `cat /tmp/depot` > /dev/null 2>&1
	fi
	echo "$1" > /tmp/boot 	
	if [ ! "$KERNEL" == "" ]; then
		echo "$1" > /root/boot
	fi
fi
