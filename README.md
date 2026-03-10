# packer-proxmox-templates

Packer templates for building Proxmox VM templates with cloud-init support.

## Templates

| Template | Description | VM ID |
|----------|-------------|-------|
| debian-13-amd64 | Debian 13 Trixie (general purpose) | 16000 |
| ubuntu-24.04-amd64 | Ubuntu 24.04 LTS Noble (general purpose) | 16010 |
| alpine-3-amd64 | Alpine 3.23 (lightweight/utility) | 16020 |
| talos-amd64 | Talos v1.12.5 (Kubernetes OS) | 16030 |

### Default Resources

| Template | Disk | RAM | Cores |
|----------|------|-----|-------|
| Debian 13 | 4G | 1024M | 1 |
| Ubuntu 24.04 | 8G | 1024M | 1 |
| Alpine 3.23 | 1G | 512M | 1 |
| Talos | 10G | 2048M | 2 |

These are template build defaults. Override per-VM after cloning in Proxmox. Disk is auto-expanded by the autogrowpart service.

## Quick Start

```bash
# 1. Install packer
# https://developer.hashicorp.com/packer/install

# 2. Configure Proxmox credentials
cp credentials.example.pkrvars.hcl credentials.pkrvars.hcl
# Edit credentials.pkrvars.hcl with your Proxmox connection details

# 3. Build a template
./build.sh debian-13
./build.sh ubuntu-24.04
./build.sh alpine-3
./build.sh talos

# Override any variable at build time
./build.sh debian-13 -var template_vm_id=9000
```

## Proxmox User Setup

Create a dedicated packer user with the required privileges:

```bash
pveum useradd packer@pve
pveum passwd packer@pve
pveum roleadd Packer -privs "VM.Config.Disk VM.Config.CPU VM.Config.Memory Datastore.AllocateSpace Sys.Modify VM.Config.Options VM.Allocate VM.Audit VM.Console VM.Config.CDROM VM.Config.Network VM.PowerMgmt VM.Config.HWType VM.Monitor"
pveum aclmod / -user packer@pve -role Packer
```

## bootstrap.sh

Debian and Ubuntu templates run `bootstrap.sh` during provisioning. It handles:

- Package installation (cloud-init, qemu-guest-agent, common utilities)
- Cloud-init datasource config for Proxmox
- Unattended security upgrades (auto-reboot disabled)
- NTP via systemd-timesyncd
- Journald log size cap (256M)
- Network sysctl hardening (ICMP redirects, SYN cookies, martian logging, reverse path filtering)
- Kernel sysctl hardening (ASLR, kptr_restrict, dmesg_restrict, ptrace_scope)
- Core dump disable (sysctl + limits.d)
- SSH hardening (9 settings via drop-in: UseDNS, root login, password auth, X11/agent forwarding, MaxAuthTries, LoginGraceTime, ClientAlive)
- `/tmp` mounted with noexec,nosuid,nodev
- Network interface and SSH fingerprint display at login (via networkd-dispatcher)
- Custom shell prompt with timestamp and colors, ls aliases
- Idle session timeout (15 min)
- Auto-grow partition service (auto-detects root device, supports ext4/xfs)
- GRUB optimization
- MOTD
- Machine-ID reset for unique identity on clone
- Template build stamp (`/etc/template-build`)

Alpine and Talos templates use their own provisioning and are not affected by this script.

## Project Structure

```
.
├── build.sh                         # Build script for all templates
├── bootstrap.sh                     # Shared provisioner for Debian/Ubuntu
├── credentials.example.pkrvars.hcl  # Proxmox connection template
├── alpine-3-amd64/                  # Alpine template
├── debian-13-amd64/                 # Debian template
├── ubuntu-24.04-amd64/              # Ubuntu template
└── talos-amd64/                     # Talos template
```
