output "nlb_public_ip" {
  description = "Public IP of the Network Load Balancer."
  value       = oci_network_load_balancer_network_load_balancer.k8s_nlb.ip_addresses[0]["ip_address"]
}

output "controlplane_private_ip" {
  description = "Private IP of the control plane node."
  value       = module.oci_compute.controlplane_node_ips[0]
}

output "worker_private_ip" {
  description = "Private IP of the worker node."
  value       = module.oci_compute.worker_node_ips[0]
}

output "ubuntu_image_name" {
  description = "The Ubuntu image used for the instances."
  value       = module.oci_ubuntu_image.image_display_name
}

output "ssh_to_controlplane" {
  description = "SSH command to connect to the control plane (requires bastion or VPN)."
  value       = "ssh ubuntu@${module.oci_compute.controlplane_node_ips[0]}"
}
