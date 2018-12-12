#!/bin/bash

#This script can create, start, stop and delete and edit xhyve or hyperkit VMs.
#It requires dd and/or qemu-img and needs the following file structures.
# $HOME/VMs/xhyve-hyperkit
#                         /images
#                         /kernels
#                         /vms
#
#It creates .ini files for the VM configurations.

#Folders to use. Change if you want to.
BASE="$HOME/VMs/xhyve-hyperkit"
folders=( "$HOME/VMs" \ 
          "$BASE" \
            "$BASE/images" \
            "$BASE/kernels" \
            "$BASE/vms" \
        )

#Mapping between Questions, Variables and possible values.
#Question-Variable separator ';'
#Value separator '|'
questions=( \
    "How many CPU cores? Enter number: ;CPU" \
    "How much RAM? Enter number: ;MEM" \
    "Harddrive type raw? (raw [y], qcow2 [n]);QCOW;0|1" \
    "Harddrive name: ;IMG" \
    "Use Network Interace? (y,n);USENET;0|1" \
    "Use RND interface? (y,n);USERND;0|1" \
    "Use ACPI? (y,n);USEACPI;0|1" \
    "Use CD? (y,n);USECD;0|1" \
    "CD Image path: ;CD" \
    )
linuxquestions=( \
    "Kernel: ;KERNEL" \
    "Intird: ;INITRD" \
    "cmdline: ;CMDLINE" \
)
BSDquestions=( \
    "APICx2 (y,n);APICx2;0|1" \
    "KERNELENV:;KERNELENV" \
    "BOOTVOLUME:;BOOTVOLUME" \
    "USERBOOT (default [1], custom [2]):;USERBOOT;${folders[4]}/userboot.so"
)
typeQuestion="Type of VM is linux? (linux [y], freebsd [n]);VMTYPE;kexec|fbsd" 

#Declare what hypervisor to use. If Docker is installed which hyperkit returns true.
hypervisor=xhyve
which hyperkit &>/dev/null
[ $? ] && hypervisor=hyperkit

function checkFileStructure() {

    #echo "Checking folder structure..."
    for i in ${folders[@]}; do
        #echo -n "$i...";
        [ -d $i ] || echo "$i does not exist. creating..."; mkdir -p $i 
    done
}


#Depends on $value and $key and userinput existing in calling function
function setKeyVal(){
key=$(echo "$1"|cut -d ";" -f 2)
echo "$1"|cut -d ";" -f 1
read userinput
if [[ $(echo $1|awk -F";" '{print NF}') -eq 3 ]]; then
        defaults=$(echo "$1"|cut -d ";" -f 3)
        if [ "$userinput" == "y" ]; then 
            value=$(echo "$defaults"|cut -d "|" -f 1)
        else
            value=$(echo "$defaults"|cut -d "|" -f 2)
        fi
else
    value="$userinput"
fi
}

function write2config(){
        setKeyVal "$1"
        echo "$key=\"$value\"">>"${folders[5]}/$vmname.ini"
}

#gets run when xhyveManager create VM-name is run.
function createVM(){
    vmname=$1
    declare userinput
    declare value
    declare key
    declare defaults
    touch "${folders[5]}/$vmname.ini"
    
    echo "UUID=\"$(uuidgen)\"" >>"${folders[5]}/$vmname.ini"
    write2config "$typeQuestion"
    if [ "$value" == "kexec" ]; then 
        for i in "${linuxquestions[@]}"; do
            write2config "$i"
        done 
    else
        for i in "${BSDquestions[@]}"; do
            write2config "$i"
        done
    fi
    for i in "${questions[@]}"; do
        write2config "$i"
    done
}

#runs VM after its config has been loaded. 
function startVM() {
    RAM="-m $MEM"
    SMP="-c $CPU"
    [ $USENET ] && NET="-s 2:0,virtio-net"
    [ $USECD -eq 0 ] && IMG_CD="-s 3:0,ahci-cd,$CD"
    [ $QCOW -eq 0 ] && IMG_HDD="-s 4:0,virtio-blk,$IMG" ||  IMG_HDD="-s 4:0,ahci-hd,$IMG" 
    [ $USERND ] && VND_RND="-s 5:0,virtio-rnd"
    PCI_DEV="-s 0:0,hostbridge -s 31,lpc"
    LPC_DEV="-l com1,stdio"
    [ $USEACPI ] && ACPI="-A"
    [ $APICx2 ] && APICx2="-x"
    if [ $VMTYPE == "kexec" ]; then 
        KERNELLINE="kexec,$KERNEL,$INITRD,$CMDLINE"
    else
        KERNELLINE="fbsd,$USERBOOT,$BOOTVOLUME,$KERNELENV"
    fi
    
  printf "sudo $hypervisor -P -H -u \n$APICx2 \n$ACPI \n$RAM \n$SMP \n$PCI_DEV \n$LPC_DEV \n$NET \n$IMG_CD \n$IMG_HDD \n$VND_RND \n-U $UUID \n-f $KERNELLINE\n"
  sudo $hypervisor -P -H -u $APICx2 $ACPI $RAM $SMP $PCI_DEV $LPC_DEV $NET $IMG_CD $IMG_HDD $VND_RND -U $UUID -f $KERNELLINE
}

#Reads Configfile of supplied name and evals it's lines to variables for later use.
#Configfile contents of form CD=bootcd.iso => variable $CD with value "bootcd.iso" after eval.
function readConfig(){
    configfile=$1.ini
    source ${folders[5]}/$configfile
}
#createVM test;
function listVMs(){
    for i in ${folders[5]}/*.ini; do
        echo ${i%.*}
    done
}

#deleteVM
function deleteVM(){
    [ "$KERNEL" != "userboot.so" ] && mv -v $KERNEL ~/.Trash/
    [ -e ${folders[4]}/$INITRD ] && mv -v ${folders[4]}/$INITRD ~/.Trash/
    [ -e ${folders[3]}/$IMG ] && mv -v ${folders[3]}/$IMG ~/.Trash/
    mv -v ${folders[5]}/$1.ini ~/.Trash/
}

checkFileStructure
case $1 in
    "") 
        echo "help" 
        ;;
    "create")
        createVM "$2"
        ;;
    "start")
        readConfig "$2" ; startVM
        ;;
    "list")
        listVMs
        ;;
    "delete")
        readConfig "$2" ; deleteVM "$2";
        ;;
esac
