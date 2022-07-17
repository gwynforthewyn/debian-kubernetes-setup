#!/bin/bash -el

echo "Setting up firewall with ufw"
apt-get install -y ufw

# https://kubernetes.io/docs/reference/ports-and-protocols/
ufw allow 6443
ufw allow 2379
ufw allow 2380
ufw allow 10250
ufw allow 10259
ufw allow 10257
ufw allow 10250

ufw allow 30000:32767/tcp 
ufw allow 30000:32767/udp

echo "Disabling swap in systemd"
for UNIT in $(systemctl list-units *swap --no-pager --no-legend --plain | awk '{ print $1 }')
do
  systemctl stop $UNIT || true
  systemctl mask $UNIT
done

# I figured these two are needed because kubeadm gives you a warning if they're not there
modprobe br_netfilter 
echo br_netfilter >> /etc/modules

sysctl -w net.ipv4.ip_forward=1
sed 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf -i

# Install containerd binary from the docker repos
# https://docs.docker.com/engine/install/debian/
 apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io
# / docker instructions

# containerd does not come preconfigured. You must configure it for either the control or worker nodes
# the kubelet will take care of making sure the cni plugin config gets put in there
containerd config default > /etc/containerd/config.toml
systemctl restart containerd

# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/#migrating-to-the-systemd-driver
# This worker is joining a cluster that already has the correct configmap, so we just need to ensure the local containerd is in
# good order
sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml


# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
apt-get install -y apt-transport-https ca-certificates curl
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
