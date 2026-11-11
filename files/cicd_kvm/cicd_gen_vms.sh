#!/bin/bash
# CAUTION: This script is more of a reference, than a usable command.
#
# Prerequisits
# Set up DNS and DHCP with fixed IP addreses for all nodes,
# configured through ansible on a service/bastion node.
#
# Set up a basic KVM hypervisor through ansible and configure SSH keys for
# ansible and root on KVM.
#
# This contents of this script is intended to be run from the KVM hypervisor.

# STEP -1: Make this script usable.
GET_ARGS=true
CICD_CREATE=false
CICD_DOWNLOAD=false
CICD_REMOVE=false
CICD_HELP=false
CICD_UNDEFINE=false
CICD_VERBOSE=false

USAGE="
$0 [OPTION]
  -c|--create           Create CICD VMs on KVM
  -d|--download         Download base ISO image. (optional)
  -h|--help             Print Usage and Exit.
  -r|--remove           Delete base ISO image. (optional)
  -u|--undefine         Destroy, Undefine and delete CICD VMs.
  -v|--verbose          Print status messages. (optional)
"

while [ "${GET_ARGS}" == "true" ]; do
  case $1 in
    -c|--create)
      CICD_CREATE=true; shift
      ;;
    -d|--download)
      CICD_DOWNLOAD=true; shift
      ;;
    -h|--help)
      CICD_HELP=true; shift
      ;;
    -r|--remove)
      CICD_REMOVE=true; shift
      ;;
    -u|--undefine)
      CICD_UNDEFINE=true; shift
      ;;
    -v|--verbose)
      CICD_VERBOSE=true; shift
      ;;
    *)
      if [ "$#" -ne "0" ]; then
        echo "Unkown Argument: $1"
        echo "Usage: $USAGE"
        exit 1
      else
        GET_ARGS=false
      fi
      ;;
   esac
done

# Hacky and wordy way to test mutual exclusivity of three variables.
if [[ "${CICD_CREATE}" == "true" && "${CICD_UNDEFINE}" == "true" ]]; then
  echo "Create and Undefine options are mutually exclusive."
  echo "Usage: $USAGE"
  exit 1
elif [ "${CICD_CREATE}" == "false" ] && [ "${CICD_UNDEFINE}" == "false" ] &&
     [ "${CICD_HELP}" == "false" ] && [ "${CICD_DOWNLOAD}" == "false" ] &&
     [ "${CICD_REMOVE}" == "false" ]; then
  echo "One of VM Create (-c), ISO Download (-d), VM Undefine (-u) or"
  echo "ISO Remove (-r) must be provided."
  echo "Usage: $USAGE"
  exit 1
elif [[ "${CICD_CREATE}" == "true"  &&  "${CICD_REMOVE}" == "true" ]] ||
     [[ "${CICD_DOWNLOAD}" == "true"  &&  "${CICD_REMOVE}" == "true" ]]; then
  echo "ISO Remove option is mutually exclusive to ISO Download and VM Create."
  echo "Usage: $USAGE"
  exit 1
fi

if [[ "${CICD_HELP}" == "true" ]]; then
  echo "Usage: $USAGE"
  exit 1
fi

# Set Variables
[ "${CICD_VERBOSE}" == "true" ] && echo "Setting up Variables . . . "
source cicd_vm_list.inc
export ARCH=x86_64
export IMGS=/var/lib/libvirt/images
export CICD_ISO_URL="https://download.fedoraproject.org"
export CICD_ISO_PATH="pub/fedora/linux/releases"
export CICD_ISO_FRAG="${CICD_ISO_VERS}/Server/${ARCH}/iso"
export CICD_ISO_DOWNLOAD="${CICD_ISO_URL}/${CICD_ISO_PATH}/${CICD_ISO_FRAG}"

if [[ "${CICD_VERBOSE}" == "true" ]]; then
  echo "VM Attributes:"
  for L in ${VM_LIST[@]}; do
    declare -n VM=${L}
    for A in ${VM_ATTR[@]}; do
      echo "${L} - ${A}: ${VM[${A}]}"
    done
  done
  echo
fi

# Remove ISO
if [[ "${CICD_REMOVE}" == "true" ]]; then
  echo "Remove ISO . . ."
  if [ -f "${IMGS}/ISOS/${CICD_ISO}" ]; then
    [ "${CICD_VERBOSE}" == "true" ] && echo "Deleting ISO . . . "
    rm -rf ${IMGS}/ISOS/${CICD_ISO}
  fi
  echo "Done."
fi

# VM Remove/Clean-up
if [[ "${CICD_UNDEFINE}" == "true" ]]; then
  echo "Removing VMs and image . . ."
  for L in ${VM_LIST[@]}; do
    declare -n VM=${L}
    [ "${CICD_VERBOSE}" == "true" ] && echo "Removing ${VM[SERVER_NAME]}"
    $(virsh list --state-running | grep ${VM[SERVER_NAME]} >& /dev/null)
    VM_RUN=$?
    $(virsh list --all | grep ${VM[SERVER_NAME]} >& /dev/null)
    VM_EXIST=$?
    if [[ "${VM_RUN}" == "0" ]]; then
      [ "${CICD_VERBOSE}" == "true" ] && echo "Stopping ${VM[SERVER_NAME]}"
      virsh destroy ${VM['SERVER_NAME']}
    else
      [ "${CICD_VERBOSE}" == "true" ] && echo "${VM[SERVER_NAME]} not running"
    fi
    if [[ "${VM_EXIST}" == "0" ]]; then
      [ "${CICD_VERBOSE}" == "true" ] && echo "Undefine ${VM[SERVER_NAME]}"
      virsh undefine ${VM[SERVER_NAME]}
    else
      [ "${CICD_VERBOSE}" == "true" ] && echo "${VM[SERVER_NAME]} doesn't exist"
    fi

    if [ -f "${IMGS}/${VM[SERVER_NAME]}.qcow2" ]; then
      [ "${CICD_VERBOSE}" == "true" ] && echo "Deleting QCOW Image . . . "
      rm -rf ${IMGS}/${VM[SERVER_NAME]}.qcow2
    else
      [ "${CICD_VERBOSE}" == "true" ] && echo "${VM[SERVER_NAME]}: No Disk Img"
    fi
    [ "${CICD_VERBOSE}" == "true" ] && echo
  done
  echo "Done."
fi

# Download ISO
if [[ "${CICD_DOWNLOAD}" == "true" ]]; then
  echo "Downloading ISO . . ."
  if [ -f "${IMGS}/ISOS/${CICD_ISO}" ]; then
    echo "${IMGS}/ISOS/${CICD_ISO} already exists."
  else
    wget -P ${IMGS}/ISOS ${CICD_ISO_DOWNLOAD}/${CICD_ISO}
    echo "Done."
  fi

fi

# Create VMs
if [[ "${CICD_CREATE}" == "true" ]]; then
  # Verify ISO is downloaded. Necessary if download flag is not set.
  if [ ! -f "${IMGS}/ISOS/${CICD_ISO}" ]; then
    echo "ISO ${CICD_ISO} is missing. Please enable download:"
    echo "Usage: $USAGE"
    exit 1
  fi

  echo "Creating images and VMs . . ."
  for L in ${VM_LIST[@]}; do
    declare -n VM=${L}

    # Create Disk Image
    if [ -f "${IMGS}/${VM[SERVER_NAME]}.qcow2" ]; then
      echo "Disk image for ${VM[SERVER_NAME]} already exists."
      echo "Please clean up existing VM's before redeploying."
      continue
    else
      [ "${CICD_VERBOSE}" == "true" ] \
        && echo "Creating image ${VM[SERVER_NAME]}.qcow2 . . ."
      qemu-img create -f qcow2 \
        ${IMGS}/${VM[SERVER_NAME]}.qcow2 ${VM[SERVER_DISK]}
    fi

    # Create VMs
    $(virsh list --all | grep ${VM[SERVER_NAME]} >& /dev/null)
    VM_EXIST=$?

    if [[ "${VM_EXIST}" == "1" ]]; then
      [ "${CICD_VERBOSE}" == "true" ] && echo "Creating ${VM[SERVER_NAME]}"
      /usr/bin/virt-install -n ${VM[SERVER_NAME]} \
        --graphics vnc \
        --noautoconsole \
        --autostart \
        --vcpus 2 \
        --ram ${VM[SERVER_MEM]} \
        --disk path=${IMGS}/${VM[SERVER_NAME]}.qcow2,format=qcow2,bus=sata,device=disk \
        --network network=${CICD_NETWORK},mac=${VM[SERVER_MAC]} \
        --cdrom "${IMGS}/ISOS/${CICD_ISO}"
    else
      echo "VM ${VM[SERVER_NAME]} already exists."
      echo "Please clean up existing VM's before redeploying."
      continue
    fi

  done
  echo "Done."

fi
