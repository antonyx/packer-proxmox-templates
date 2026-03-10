build {
  sources = [
    "source.file.preseed",
    "source.proxmox-iso.debian",
  ]

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

  # Cleanup & Disable packer provisioner access
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
      "rm -rf /etc/sudoers.d/packer",
    ]
  }

}
