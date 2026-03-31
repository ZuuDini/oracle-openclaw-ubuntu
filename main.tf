resource "oci_identity_compartment" "compartment" {
  compartment_id = var.tenancy_ocid
  description    = var.compartment_description
  name           = var.compartment_name
}

module "oci_vcn" {
  source = "oracle-terraform-modules/vcn/oci"

  compartment_id                = oci_identity_compartment.compartment.id
  create_internet_gateway       = true
  create_nat_gateway            = true
  create_service_gateway        = true
  internet_gateway_display_name = var.internet_gateway_display_name
  nat_gateway_display_name      = var.nat_gateway_display_name
  vcn_name                      = var.vcn_name

  subnets = {
    public = {
      cidr_block = "10.0.0.0/24"
      name       = var.public_subnet_name
      type       = "public"
    }
    private = {
      cidr_block = "10.0.1.0/24"
      name       = var.private_subnet_name
      type       = "private"
    }
  }
}

resource "oci_core_default_security_list" "default_security_list" {
  manage_default_resource_id = module.oci_vcn.default_security_list_id
  display_name               = "Default Security List for ${var.vcn_name}"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "${module.oci_vcn.nat_gateway_all_attributes[0].nat_ip}/32"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "${oci_network_load_balancer_network_load_balancer.k8s_nlb.ip_addresses[0]["ip_address"]}/32"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/8"
  }

  ingress_security_rules {
    protocol = "all"
    source   = "${var.personal_ip}/32"
  }

  ingress_security_rules {
    protocol = 6
    source   = "0.0.0.0/0"

    tcp_options {
      max = 6443
      min = 6443
    }
  }

  ingress_security_rules {
    protocol = 6
    source   = "0.0.0.0/0"

    tcp_options {
      max = 22
      min = 22
    }
  }

  ingress_security_rules {
    protocol = 6
    source   = "0.0.0.0/0"

    tcp_options {
      max = 30000
      min = 30000
    }
  }
}

module "oci_ubuntu_image" {
  source = "./modules/oci_ubuntu_image"

  compartment_id = oci_identity_compartment.compartment.id
  ubuntu_version = var.ubuntu_version
}

resource "oci_network_load_balancer_network_load_balancer" "k8s_nlb" {
  compartment_id = oci_identity_compartment.compartment.id
  display_name   = "k8s-nlb"
  is_private     = false
  subnet_id      = module.oci_vcn.subnet_all_attributes["public"]["id"]
}

locals {
  nlb_ip             = oci_network_load_balancer_network_load_balancer.k8s_nlb.ip_addresses[0]["ip_address"]
  cluster_endpoint   = var.cluster_domain_endpoint != "" ? var.cluster_domain_endpoint : local.nlb_ip
  kubernetes_version = var.kubernetes_version

  controlplane_cloud_init = <<-EOF
    #!/bin/bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive

    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab

    # Load required kernel modules
    cat > /etc/modules-load.d/k8s.conf <<MODULES
    overlay
    br_netfilter
    MODULES
    modprobe overlay
    modprobe br_netfilter

    # Sysctl settings for Kubernetes networking
    cat > /etc/sysctl.d/k8s.conf <<SYSCTL
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    net.core.rmem_max                   = 2500000
    net.core.wmem_max                   = 2500000
    SYSCTL
    sysctl --system

    # Install containerd
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg containerd

    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    # Install kubeadm, kubelet, kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    systemctl enable kubelet

    # Initialize the cluster
    kubeadm init \
      --control-plane-endpoint="${local.cluster_endpoint}:6443" \
      --pod-network-cidr=10.244.0.0/16 \
      --upload-certs

    # Set up kubeconfig for ubuntu user
    mkdir -p /home/ubuntu/.kube
    cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown -R ubuntu:ubuntu /home/ubuntu/.kube

    # Generate and save join command for workers
    kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
    chmod 600 /home/ubuntu/join-command.sh
    chown ubuntu:ubuntu /home/ubuntu/join-command.sh
  EOF

  worker_cloud_init = <<-EOF
    #!/bin/bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive

    # Disable swap
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab

    # Load required kernel modules
    cat > /etc/modules-load.d/k8s.conf <<MODULES
    overlay
    br_netfilter
    MODULES
    modprobe overlay
    modprobe br_netfilter

    # Sysctl settings for Kubernetes networking
    cat > /etc/sysctl.d/k8s.conf <<SYSCTL
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    net.core.rmem_max                   = 2500000
    net.core.wmem_max                   = 2500000
    SYSCTL
    sysctl --system

    # Install containerd
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg containerd

    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl restart containerd
    systemctl enable containerd

    # Install kubeadm, kubelet, kubectl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl
    systemctl enable kubelet

    # The worker will need to join the cluster manually after the control plane is ready.
    # SSH into the control plane, get the join command from /home/ubuntu/join-command.sh,
    # then run it on this worker node.
  EOF
}

module "oci_compute" {
  source = "./modules/oci_compute"

  ad_number              = var.ad_number
  arm64_image_id         = module.oci_ubuntu_image.arm64_image_id
  compartment_id         = oci_identity_compartment.compartment.id
  controlplane_user_data = local.controlplane_cloud_init
  nlb_id                 = oci_network_load_balancer_network_load_balancer.k8s_nlb.id
  ssh_public_key         = var.ssh_public_key
  subnet_id              = module.oci_vcn.subnet_all_attributes["private"]["id"]
  worker_user_data       = local.worker_cloud_init
}
