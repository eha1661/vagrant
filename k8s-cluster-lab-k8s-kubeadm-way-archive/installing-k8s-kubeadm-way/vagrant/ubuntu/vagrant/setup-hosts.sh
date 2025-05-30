#!/bin/bash
set -ex
IFNAME=$1
ADDRESS="$(ip -4 addr show $IFNAME | grep "inet" | head -1 |awk '{print $2}' | cut -d/ -f1)"
NETWORK=$(echo $ADDRESS | awk 'BEGIN {FS="."} ; { printf("%s.%s.%s", $1, $2, $3) }')
sed -e "s/^.*${HOSTNAME}.*/${ADDRESS} ${HOSTNAME} ${HOSTNAME}.local/" -i /etc/hosts

# # remove ubuntu-jammy entry
sed -e '/^.*ubuntu-jammy.*/d' -i /etc/hosts
sed -e "/^.*$2.*/d" -i /etc/hosts

# Update /etc/hosts about other hosts
cat >> /etc/hosts <<EOF
${NETWORK}.11  kubemaster-1
${NETWORK}.21  kubenode01

EOF

# ${NETWORK}.12  kubemaster-2

# ${NETWORK}.23  kubenode02
# ${NETWORK}.23  kubenode03
# ${NETWORK}.31  loadbalancer-1