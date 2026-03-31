output "arm64_image_id" {
  value = data.oci_core_images.ubuntu_arm64.images[0].id
}

output "image_display_name" {
  value = data.oci_core_images.ubuntu_arm64.images[0].display_name
}
