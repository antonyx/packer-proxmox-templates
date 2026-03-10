#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "removing X11 packages (server not desktop...)"
apt-get -y remove libx11.* || true

echo "update and upgrade remaining packages"
apt-get -y update
apt-get -y upgrade

echo "install some basic utilities; cloud-guest for growpart"
apt-get -y install curl psmisc net-tools \
 cloud-guest-utils qemu-guest-agent cloud-init \
 procps iputils-ping netcat-traditional mc wget dnsutils iproute2 vim nano tcpdump \
 apt-transport-https ca-certificates gnupg2 \
 htop tmux msmtp-mta rsync iptables \
 networkd-dispatcher unattended-upgrades

echo "configure cloud-init for Proxmox"
echo 'datasource_list: [ NoCloud, ConfigDrive, None ]' > /etc/cloud/cloud.cfg.d/99_pve.cfg
chmod 644 /etc/cloud/cloud.cfg.d/99_pve.cfg

echo "configure unattended-upgrades"
mkdir -p /etc/apt/apt.conf.d
cat > /etc/apt/apt.conf.d/50unattended-upgrades-local << "EOF"
Unattended-Upgrade::Automatic-Reboot "false";
EOF
chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades-local

echo "enable NTP via systemd-timesyncd"
timedatectl set-ntp true

echo "cap journald log size"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-log-size.conf << "EOF"
[Journal]
SystemMaxUse=256M
EOF
chmod 644 /etc/systemd/journald.conf.d/99-log-size.conf

echo "sysctl network hardening"
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-hardening.conf << "EOF"
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN cookies
net.ipv4.tcp_syncookies = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable core dumps (prevent sensitive data leaking to disk)
fs.suid_dumpable = 0

# Kernel hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
kernel.yama.ptrace_scope = 1
EOF
chmod 644 /etc/sysctl.d/99-hardening.conf

echo "Disable core dumps via limits"
mkdir -p /etc/security/limits.d
cat > /etc/security/limits.d/99-no-core.conf << "EOF"
*    hard    core    0
EOF
chmod 644 /etc/security/limits.d/99-no-core.conf

echo "Harden /tmp with noexec,nosuid,nodev"
if [ -f /usr/share/systemd/tmp.mount ]; then
  cp /usr/share/systemd/tmp.mount /etc/systemd/system/tmp.mount
elif [ -f /usr/lib/systemd/system/tmp.mount ]; then
  cp /usr/lib/systemd/system/tmp.mount /etc/systemd/system/tmp.mount
fi
sed -i 's/^Options=.*/Options=mode=1777,strictatime,nosuid,nodev,noexec/' /etc/systemd/system/tmp.mount
systemctl enable tmp.mount

echo "Create a script to display IP and SSH fingerprint on login console"
cp -v /etc/issue /etc/issue.original

mkdir -p /etc/networkd-dispatcher/routable.d
cat > /etc/networkd-dispatcher/routable.d/show-ip-address << "EOF"
#!/bin/bash
cp /etc/issue.original /etc/issue
printf "SSH key fingerprint: \n$(ssh-keygen -l -f /etc/ssh/ssh_host_ecdsa_key.pub)\n\n" >> /etc/issue
printf "Server Network Interface: $(ip -4 -br addr | sed -n '2p')\n\n" >> /etc/issue
EOF
chmod +x /etc/networkd-dispatcher/routable.d/show-ip-address

echo "SSH hardening"
cat > /etc/ssh/sshd_config.d/99-hardening.conf << "EOF"
UseDNS no
PermitRootLogin prohibit-password
PasswordAuthentication no
X11Forwarding no
AllowAgentForwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
chmod 644 /etc/ssh/sshd_config.d/99-hardening.conf

echo "Customize prompt and ls colors for all users"
cat > /etc/profile.d/99-prompt.sh << "EOF"
export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias la='ls $LS_OPTIONS -la'
export PS1="[\t] \[\e[0;01;33m\]\u@\H\[\e[0m\]:\$PWD\[\e[0;41m\]\\$\[\e[0m\] "
EOF
chmod 644 /etc/profile.d/99-prompt.sh

echo "Set idle session timeout"
cat > /etc/profile.d/99-timeout.sh << "EOF"
# Auto-logout idle sessions after 15 minutes
TMOUT=900
readonly TMOUT
export TMOUT
EOF
chmod 644 /etc/profile.d/99-timeout.sh

echo "Add a nice greeting - motd"
[ -f /etc/motd ] && mv /etc/motd /etc/motd.original || true

cat > /etc/update-motd.d/20-motd-welcome << "EOF"
#!/bin/bash
source /etc/os-release
echo ""
echo " Welcome to $PRETTY_NAME Server"
echo ""
EOF
chmod +x /etc/update-motd.d/20-motd-welcome

echo "Automatically Grow Partition after resize by Proxmox"
cat > /etc/systemd/system/autogrowpart.service << "EOF"
[Unit]
Description=Automatically Grow Partition after resize by Proxmox.

[Service]
Type=simple
ExecStart=/bin/bash /usr/local/bin/auto_grow_partition.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /etc/systemd/system/autogrowpart.service

cat > /usr/local/bin/auto_grow_partition.sh << "EOF"
#!/bin/bash
# Auto-detect root device and partition
ROOT_SOURCE=$(findmnt -n -o SOURCE /)
ROOT_DISK=$(lsblk -n -o PKNAME "$ROOT_SOURCE" | head -1)
ROOT_PARTNUM=$(lsblk -n -o PARTN "$ROOT_SOURCE" | head -1)
ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)

if [ -z "$ROOT_DISK" ] || [ -z "$ROOT_PARTNUM" ]; then
    echo "ERROR: could not detect root device"
    exit 1
fi

growpart -N "/dev/$ROOT_DISK" "$ROOT_PARTNUM"
if [ $? -eq 0 ]; then
    echo "* auto-growing /dev/${ROOT_DISK} partition ${ROOT_PARTNUM}"
    growpart "/dev/$ROOT_DISK" "$ROOT_PARTNUM"
    case "$ROOT_FSTYPE" in
        ext4|ext3|ext2)
            resize2fs "$ROOT_SOURCE"
            ;;
        xfs)
            xfs_growfs /
            ;;
        *)
            echo "WARNING: unsupported filesystem type $ROOT_FSTYPE"
            ;;
    esac
fi
EOF
chmod +x /usr/local/bin/auto_grow_partition.sh
systemctl enable autogrowpart

echo "optimize grub"
sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=\).*/\1\"\"/g' /etc/default/grub
sed -i 's/\(GRUB_TIMEOUT_STYLE=\).*/\1\"menu\"/g' /etc/default/grub
sed -i 's/\(GRUB_TIMEOUT=\).*/\1\"0\"/g' /etc/default/grub
sed -i 's/.*\(GRUB_TERMINAL=.*\)/#\1/g' /etc/default/grub
update-grub

echo "cleaning up apt"
# purging packages which are no longer needed
apt-get -y autoremove
apt-get -y clean

echo "cleaning up dhcp leases"
rm -fv /var/lib/dhcp/* 2>/dev/null

echo "cleaning bash history"
unset HISTFILE
rm -fv ~/.bash_history 2>/dev/null

echo "write template build stamp"
source /etc/os-release
cat > /etc/template-build << STAMP
Template build: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
OS: ${PRETTY_NAME}
Kernel: $(uname -r)
Packages: $(dpkg -l | grep -c '^ii') installed
STAMP
chmod 644 /etc/template-build

echo "reset machine-id for unique identity on clone"
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "minimize image size"
dd if=/dev/zero of=/EMPTY bs=1M || true
rm -f /EMPTY

exit 0
