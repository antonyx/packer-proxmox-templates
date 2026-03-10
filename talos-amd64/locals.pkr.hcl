locals {
  talos_factory_url = "https://factory.talos.dev"

  http_url = join("", ["http://", coalesce(var.http_server_host, "{{ .HTTPIP }}"), ":", coalesce(var.http_server_port, "{{ .HTTPPort }}")])

  use_iso_file = var.boot_iso_file != null ? true : false

  template_name        = "talos-${var.talos_version}-nocloud"
  template_description = "Talos Linux ${var.talos_version}"

  cloud_init_storage_pool = coalesce(var.cloud_init_storage_pool, var.disk_storage_pool)

  disk_device = var.disk_type == "virtio" ? "/dev/vda" : "/dev/sda"
  ga_path     = var.disk_type == "virtio" ? "/dev/vport1p1" : "/dev/vport2p1"
}
