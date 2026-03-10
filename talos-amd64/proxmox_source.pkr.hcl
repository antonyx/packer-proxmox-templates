source "proxmox-iso" "talos" {
  proxmox_url              = "https://${var.proxmox_host}:${var.proxmox_port}/api2/json"
  node                     = var.proxmox_node
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_skip_verify_tls

  template_name        = coalesce(var.template_name, local.template_name)
  template_description = coalesce(var.template_description, local.template_description)
  vm_id                = var.template_vm_id

  boot_iso {
    iso_url          = local.use_iso_file ? null : var.boot_iso_url
    iso_storage_pool = var.boot_iso_storage_pool
    iso_file         = local.use_iso_file ? "${var.boot_iso_storage_pool}:iso/${var.boot_iso_file}" : null
    iso_checksum     = var.boot_iso_checksum
    unmount          = true
  }

  os         = "l26"
  qemu_agent = true
  memory     = var.memory
  cores      = var.cores
  sockets    = var.sockets

  scsi_controller = "virtio-scsi-pci"

  network_adapters {
    model  = "virtio"
    bridge = var.network_bridge
  }

  disks {
    disk_size    = var.disk_size
    storage_pool = var.disk_storage_pool
    format       = var.disk_format
    type         = var.disk_type
  }

  http_directory    = "http"
  http_bind_address = var.http_bind_address
  http_interface    = var.http_interface
  http_port_min     = var.http_server_port
  http_port_max     = var.http_server_port
  vm_interface      = var.vm_interface

  boot      = null
  boot_wait = "30s"
  boot_command = [
    "root<enter><wait>",
    "passwd<enter>${var.ssh_password}<enter>${var.ssh_password}<enter><wait>",
    "ifconfig eth0 up && udhcpc -i eth0<enter><wait5>",
    "setup-apkrepos -1 -c<enter><wait5>",
    "apk update<enter><wait>",
    "apk add ca-certificates curl openssh qemu-guest-agent<enter><wait>",
    "curl -L ${local.http_url}/schematic.yaml -o /tmp/schematic.yaml<enter><wait>",
    "sed -r -i 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config<enter><wait>",
    "sed -r -i 's/^#?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config<enter><wait>",
    "echo GA_PATH=\"${local.ga_path}\" >> /etc/conf.d/qemu-guest-agent<enter><wait>",
    "rc-service qemu-guest-agent restart<enter><wait>",
    "rc-service sshd restart<enter><wait>",
  ]

  ssh_handshake_attempts    = 100
  ssh_username              = "root"
  ssh_password              = var.ssh_password
  ssh_clear_authorized_keys = true
  ssh_timeout               = "10m"

  cloud_init              = true
  cloud_init_storage_pool = local.cloud_init_storage_pool

}
