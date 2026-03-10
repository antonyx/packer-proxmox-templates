build {
  sources = [
    "source.file.meta_data",
    "source.file.user_data",
    "source.proxmox-iso.ubuntu"
  ]

  # Wait for cloud-init to complete after reboot
  provisioner "shell" {
    inline = ["while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"]
  }

  # Upload and run bootstrap script
  provisioner "file" {
    source      = "../bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }};"
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "/tmp/bootstrap.sh",
      "rm -f /tmp/bootstrap.sh",
    ]
  }

  # Clean up subiquity installer
  provisioner "shell" {
    execute_command = "sudo /bin/sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "cloud-init clean --machine-id --logs",
      "if [ -f /etc/cloud/cloud.cfg.d/99-installer.cfg ]; then rm /etc/cloud/cloud.cfg.d/99-installer.cfg; echo 'Deleting subiquity cloud-init config'; fi",
      "if [ -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg ]; then rm /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg; echo 'Deleting subiquity cloud-init network config'; fi",
    ]
  }

  # Disable packer provisioner access
  provisioner "shell" {
    environment_vars = [
      "SSH_USERNAME=${var.ssh_username}"
    ]
    skip_clean      = true
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}; rm -f {{ .Path }}"
    inline = [
      "shred -u /etc/ssh/*_key /etc/ssh/*_key.pub",
      "unset HISTFILE; rm -rf /home/*/.*history /root/.*history",
      "passwd -d $SSH_USERNAME",
      "passwd -l $SSH_USERNAME",
      "rm -rf /home/$SSH_USERNAME/.ssh/authorized_keys",
      "rm -f /etc/sudoers.d/90-cloud-init-users",
    ]
  }

}
