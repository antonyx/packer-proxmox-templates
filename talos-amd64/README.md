# Talos Linux AMD64 Packer Template

Builds a Proxmox VM template with [Talos Linux](https://www.talos.dev/) written to disk.

Uses Alpine Linux virt ISO as a temporary build environment to bootstrap the
Talos image onto the VM disk via SSH.

The Talos image includes the qemu-guest-agent extension via the
[Talos Factory API](https://factory.talos.dev/). Extensions are defined in
`templates/schematic.yaml.pkrtpl.hcl`.

## Run examples

```bash
packer build -var-file=talos-1.12.5.pkrvars.hcl -var-file=credentials.pkrvars.hcl .
```
