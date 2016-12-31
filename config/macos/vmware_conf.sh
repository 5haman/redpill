#!/bin/bash

VMNAME="hyperdock"
DHCP_CONF="/Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf"
VMNET_CLI="/Applications/VMware Fusion.app/Contents/Library/vmnet-cli"

MAC=`cat "$HOME/Documents/Virtual Machines.localized/$VMNAME.vmwarevm/$VMNAME.vmx" \
| grep "ethernet0.address = " | awk -F" = " '{ print $2 }' | tr -d '"'`

DHCP="
host hyperdock {
    hardware ethernet $MAC;
    fixed-address 192.168.48.48;
}"

echo "Enter your admin password to continue..."
sudo echo -n

if ! grep --quiet "hyperdock" "$DHCP_CONF"; then
    sudo bash -c "echo \"$DHCP\" >>\"$DHCP_CONF\""
    sudo "$VMNET_CLI" --stop
    sudo "$VMNET_CLI" --start
fi

if ! grep --quiet "hyperdock" "/etc/hosts"; then
    sudo bash -c "echo \"192.168.48.48 hyperdock\" >>/etc/hosts"
fi

open "http://hyperdock"
