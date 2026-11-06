## Generate Test Host on KVM from a Fedora-Cloud-Base-Generic QCOW2 image.

```
virt-install \
   --name libvirt.test \
   --noautoconsole \
   --import \
   --memory 1024 \
   --vcpus=1 \
   --osinfo fedora-unknown \
   --disk bus=virtio,path=/var/lib/libvirt/images/libvirt.test.qcow2 \
   --network network:scottworks \
   --cloud-init root-password-generate=on,disable=on,root-ssh-key=/root/.ssh/okd_rsa.pub,clouduser-ssh-key=/root/.ssh/okd_rsa.pub
```

## Network Interface Configuration

The interface configuration tasks are based on the following commands.

```
IP="192.168.1.140/24"
GATEWAY="192.168.1.1"
IF_NAME="enp1s0"
BRIDGE_NAME="swn0"
DNS="192.168.1.10,208.67.222.222"
DOMAIN="scottworks.net"

nmcli connection add type bridge \
  ifname "${BRIDGE_NAME}" \
  con-name "${BRIDGE_NAME}" \ 
  ipv4.method manual \
  ipv4.addresses "${IP}" \
  ipv4.gateway "${GATEWAY}"

nmcli con add type bridge-slave \
  ifname "${IF_NAME}" \ 
  con-name "${BRIDGE_NAME}-slave" \ 
  master "${BRIDGE_NAME}"

nmcli connection modify "${BRIDGE_NAME}" ipv4.dns "${DNS}"
nmcli connection modify "${BRIDGE_NAME}" ipv4.dns-search "${DOMAIN}"

nmcli con del "${IF_NAME}"; nmcli con reload "${BRIDGE_NAME}" &
```

## Undo Network Interface Configuration

```
nmcli connection add type ethernet \
  ifname "${IF_NAME}" \
  con-name "${IF_NAME}" \
  ipv4.method manual \
  ipv4.addresses "${IP}" \
  ipv4.gateway "${GATEWAY}"

nmcli connection modify "${IF_NAME}" ipv4.dns "${DNS}"
nmcli connection modify "${IF_NAME}" ipv4.dns-search "${DOMAIN}"

nmcli con del "${BRIDGE_NAME}-slave"; nmcli con reload "${IF_NAME}" &
nmcli con del "${BRIDGE_NAME}"
```
