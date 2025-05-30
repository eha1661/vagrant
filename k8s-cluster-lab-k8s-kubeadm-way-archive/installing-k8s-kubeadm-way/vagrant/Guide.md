# Install K8s the Kubeadm way

## Envirenment

We are using Ubuntu `18.04` distiribution

## Bootstrapping Kubernetes cluster

### 1. Install `containerd` on all nodes

* Install and configure prerequisites [`3`]

    ``` sh
    # Forwarding IPv4 and letting iptables see bridged traffic
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter

    # sysctl params required by setup, params persist across reboots
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    # Apply sysctl params without reboot
    sudo sysctl --system
    ```

    ``` sh
    sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
    ```

* Install `containerd` [`4`-`5`]

    ``` sh 
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    ```

    ``` sh
    # Install containerd
    sudo apt-get install containerd.io 
    ```

    ``` sh 
    # Check containerd service
    systemctl status containerd
    ```

* make sure that both kubelet and containerd run the same `cgoup` drive (systemd, cgroupfs)

    ``` sh
    # Check current driver
    ps -p 1
    ```

* In order to set the cgroup driver to `systemd` for `containerd`, replace the configuration file below [`3`]
    > /etc/containerd/config.toml

    ``` sh
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
    ```

    ``` sh
    sudo systemctl restart containerd
    ```

### 2. Installing kubeadm, kubelet and kubectl 

We chose the the packager manager to install compenents and dependecies. The chosen repository is `Kubernetes package repositories`.

The installation is for kubernetes `1.28`

Apply these commands for all nodes [`2`]

* Update the apt package index and install packages needed to use the Kubernetes apt repository

    ``` sh
    sudo apt-get update
    # apt-transport-https may be a dummy package; if so, you can skip that package
    sudo apt-get install -y apt-transport-https ca-certificates curl
    ```

* Download the public signing key for the Kubernetes package repositories

    ``` sh
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    ```

* Add the appropriate Kubernetes apt repository

    ``` sh
    # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    ```

* Update the apt package index, install kubelet, kubeadm and kubectl

    ``` sh
    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    ```

* Chech installation

    ``` sh
    # kubeadm
    kubeadm version
    ```

    > kubeadm version: &version.Info{Major:"1", Minor:"28", GitVersion:"v1. ...

    ``` sh
    # kubelet
    kubelet --version
    ```

    > Kubernetes v1.28.1

    ``` sh
    # kubectl
    kubectl version
    ```

    > Client Version: v1.28.1 ...

### 3. Creating Cluster

This installation if for single control-plane Kubernetes cluster.

Use ```kubeadm help``` to explore the kubeadm utility
```kubeadm init --help``` has a detailed description for bootstrapping process ...

#### 3.1 Initializing your control-plane node

Common used flags are:
  
* `pod-network-cidr` : pod network, for instance `10.244.0.0/16`    [Private Address Ranges](https://www.ibm.com/docs/en/networkmanager/4.2.0?topic=translation-private-address-ranges)
* `apiserver-advertise-address` : The IP address the API Server
* `control-plane-endpoint` : IP address or DNS name for the control plane (in case of high avialibility, it points to the load balancer)
* `dry-run`

``` sh 
sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --apiserver-advertise-address=192.168.56.11
```
> kubeadm join 192.168.56.11:6443 --token 3ycc3i.kujy2er3ptj698dc \
        --discovery-token-ca-cert-hash sha256:0bbdab7205056c464584493aa13b7b1852d6eda1d7a8b092318cf21a0b25247f

he kubectl tool uses kubeconfig files to find the information it needs to choose a cluster and communicate with the API server of a cluster.

One way to configure the access to Kubeconfig is using environment variables if you are root user.
``` sh
export KUBECONFIG=/etc/kubernetes/admin.conf
```
OR as a regular user:
``` sh
mkdir ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 3.2 Setting up Pod network

Install a networking addon `Weave Net`  [`7``8`]

``` sh
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

Make sure that the `IPALLOC_RANGE` variable in the ds `weavenet` correspond to the network for pods

``` sh
kubectl edit ds weave-net -n kube-system
```

Add this block of varible when editting the weave-net
``` yaml
      containers:
        - name: weave
          env:
            - name: IPALLOC_RANGE
              value: 10.244.0.0/16
```

#### 3.3 Joining the node to the cluster

Use the command provided and the end of `kubeadm init ...`
``` sh
sudo kubeadm join 192.168.56.11:6443 --token 3ycc3i.kujy2er3ptj698dc \
        --discovery-token-ca-cert-hash sha256:0bbdab7205056c464584493aa13b7b1852d6eda1d7a8b092318cf21a0b25247f
```

## Resources

* [`1` setup-kubernetes-cluster-kubeadm](https://devopscube.com/setup-kubernetes-cluster-kubeadm/)
* [`2` Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
* [`3` Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
* [`4` Docker Doc](https://docs.docker.com/engine/install/ubuntu/)
* [`5` Repo Containerd](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
* [`6` Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)
* [`7` Installing Addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)
* [`8` Weave Net Addon](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/)
* [vagrant file](https://github.com/kodekloudhub/certified-kubernetes-administrator-course/blob/master/Vagrantfile)
* [Kubeconfig File Explained With Practical Examples](https://devopscube.com/kubernetes-kubeconfig-file/)
* [about-kubeconfig](https://cloud.google.com/anthos/clusters/docs/multi-cloud/aws/concepts/about-kubeconfig)
