# Oracle Cloud Ubuntu Kubernetes

This repository provisions a Kubernetes cluster on Oracle Cloud Infrastructure (OCI) using Ubuntu ARM64 instances with kubeadm. It targets the Oracle Always Free tier using `VM.Standard.A1.Flex` Ampere A1 instances.

## What This Repository Creates

- A dedicated OCI compartment.
- A VCN with a public subnet (`10.0.0.0/24`), a private subnet (`10.0.1.0/24`), internet/NAT/service gateways.
- A security list allowing SSH (22), Kubernetes API (6443), NodePort (30000), and internal traffic.
- One public OCI Network Load Balancer for the Kubernetes API.
- One Ubuntu ARM64 control plane instance and one Ubuntu ARM64 worker instance in the private subnet.
- Cloud-init scripts that install containerd, kubeadm, kubelet, and kubectl on each node.
- The control plane is automatically initialized with `kubeadm init`.

## Current Topology

- `1 control plane + 1 worker` deployment.
- Both nodes use the `VM.Standard.A1.Flex` ARM shape with `2` OCPUs, `12` GB RAM, and `100` GB boot volumes.
- Nodes are accessible via SSH with your provided public key.
- Ubuntu 24.04 LTS (default, configurable).
- Kubernetes version defaults to `1.31` apt repository.

## Prerequisites

- [Terraform CLI](https://developer.hashicorp.com/terraform/install) (>= 1.5.0)
- An Oracle Cloud account (preferably with Always Free tier ARM capacity)
- An [Oracle API key](https://cloud.oracle.com/identity/domains/my-profile/api-keys)
- An SSH key pair for instance access
- [kubectl](https://kubernetes.io/docs/tasks/tools) for cluster interaction

## Variables

### Required

| Variable | Description |
|----------|-------------|
| `fingerprint` | OCI API key fingerprint |
| `private_key` | Base64-encoded OCI private key |
| `region` | OCI region (e.g. `us-ashburn-1`) |
| `tenancy_ocid` | OCI tenancy OCID |
| `user_ocid` | OCI user OCID |
| `personal_ip` | Your public IPv4 address for security list access |
| `ssh_public_key` | SSH public key for Ubuntu instance access |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `ubuntu_version` | `24.04` | Ubuntu version for OCI marketplace image |
| `kubernetes_version` | `1.31` | Kubernetes apt repo version (major.minor) |
| `cluster_domain_endpoint` | `""` | DNS hostname for the cluster API endpoint |
| `ad_number` | `1` | OCI availability domain number |
| `compartment_name` | `default-compartment` | OCI compartment name |

## Steps

1. Create an Oracle Cloud account and generate an API key.
2. Clone this repository.
3. Set your Terraform variables (via `terraform.tfvars`, environment, or Terraform Cloud).
4. Run `terraform init && terraform apply`.
5. SSH into the control plane node to retrieve the kubeconfig:

   ```bash
   ssh ubuntu@<controlplane_ip>
   cat /home/ubuntu/.kube/config
   ```

6. Get the join command for the worker from the control plane:

   ```bash
   ssh ubuntu@<controlplane_ip>
   cat /home/ubuntu/join-command.sh
   ```

7. SSH into the worker and run the join command:

   ```bash
   ssh ubuntu@<worker_ip>
   sudo <paste join command here>
   ```

8. Verify the cluster:

   ```bash
   kubectl get nodes
   ```

## Post-Deployment

After the cluster is running, you can install a CNI (e.g. Cilium, Flannel, Calico) and any GitOps tooling (e.g. FluxCD, ArgoCD) as needed:

```bash
# Example: Install Cilium
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system

# Example: Install Flannel (simpler alternative)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## Notes

- Nodes are in a private subnet. You need a bastion host, VPN, or OCI Cloud Shell to SSH into them.
- The control plane cloud-init runs `kubeadm init` automatically on first boot. The worker installs all prerequisites but requires manual join.
- The default Ubuntu user is `ubuntu`.
- Oracle's Always Free tier provides 4 OCPUs and 24 GB RAM total for A1 instances.
