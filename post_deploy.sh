#!/bin/bash

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "Please run as root"
    exit 1
fi

# Load environment variables
set -a
source .env
set +a

# Install additional security packages
print_status "Installing additional security packages..."
apt-get update
apt-get install -y \
    fail2ban \
    ufw \
    apparmor \
    clamav \
    clamav-daemon \
    rkhunter \
    chkrootkit \
    auditd \
    aide \
    logwatch \
    unattended-upgrades \
    apt-listchanges \
    needrestart \
    debsums \
    lynis

# Initialize AIDE database
print_status "Initializing AIDE database..."
aideinit

# Configure system auditing
print_status "Configuring system auditing..."
cat << EOF > /etc/audit/rules.d/audit.rules
# Delete all existing rules
-D

# Buffer Size
-b 8192

# Failure Mode
-f 1

# Monitor audit logs
-w /var/log/audit/ -k auditlog

# Monitor audit configuration files
-w /etc/audit/ -p wa -k auditconfig
-w /etc/libaudit.conf -p wa -k auditconfig
-w /etc/audisp/ -p wa -k audispconfig

# Monitor system configuration changes
-w /etc/passwd -p wa -k auth
-w /etc/group -p wa -k auth
-w /etc/shadow -p wa -k auth
-w /etc/sudoers -p wa -k auth
-w /etc/sudoers.d/ -p wa -k auth

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd
EOF

# Restart auditd
service auditd restart

# Configure logwatch
print_status "Configuring logwatch..."
cat << EOF > /etc/logwatch/conf/logwatch.conf
Output = mail
Format = html
MailTo = ${ADMIN_EMAIL:-root}
MailFrom = Logwatch
Detail = High
Service = All
Range = yesterday
EOF

# Configure rkhunter
print_status "Configuring rkhunter..."
cat << EOF > /etc/rkhunter.conf.local
MAIL-ON-WARNING=${ADMIN_EMAIL:-root}
ALLOW_SSH_ROOT_USER=no
ALLOW_SSH_PROT_V1=0
EOF
rkhunter --propupd

# Configure ClamAV
print_status "Configuring ClamAV..."
cat << EOF > /etc/clamav/clamd.conf
LogFile /var/log/clamav/clamav.log
LogTime yes
LogSyslog yes
LogFacility LOG_LOCAL6
LogVerbose yes
DatabaseDirectory /var/lib/clamav
LocalSocket /var/run/clamav/clamd.ctl
FixStaleSocket yes
MaxDirectoryRecursion 20
FollowDirectorySymlinks yes
FollowFileSymlinks yes
ReadTimeout 180
MaxThreads 12
MaxConnectionQueueLength 15
SelfCheck 3600
EOF

# Configure Docker security
print_status "Configuring Docker security..."
mkdir -p /etc/docker
cat << EOF > /etc/docker/daemon.json
{
    "live-restore": true,
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "userland-proxy": false,
    "no-new-privileges": true,
    "selinux-enabled": true,
    "userns-remap": "default",
    "dns": ["1.1.1.1", "8.8.8.8"],
    "default-ulimits": {
        "nofile": {
            "Name": "nofile",
            "Hard": 64000,
            "Soft": 64000
        }
    },
    "seccomp-profile": "/etc/docker/seccomp-profile.json"
}
EOF

# Run system hardening
print_status "Running system hardening script..."
if [ -f "./harden_ubuntu.sh" ]; then
    chmod +x ./harden_ubuntu.sh
    ./harden_ubuntu.sh
else
    print_status "Error: harden_ubuntu.sh not found"
    exit 1
fi

# Set up automatic security updates
print_status "Configuring automatic security updates..."
cat << EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::DevRelease "auto";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Configure fail2ban for Docker logs
print_status "Configuring fail2ban for Docker..."
cat << EOF > /etc/fail2ban/jail.d/docker-odoo.conf
[docker-odoo]
enabled = true
filter = docker-odoo
action = iptables-multiport[name=docker-odoo, port="80,443,8069,8072"]
logpath = /var/lib/docker/containers/*/*.log
findtime = 600
bantime = 3600
maxretry = 5
EOF

cat << EOF > /etc/fail2ban/filter.d/docker-odoo.conf
[Definition]
failregex = ^.*POST .*login.* 401.*$
            ^.*Unauthorized login attempt from <HOST>.*$
ignoreregex =
EOF

# Restart services
print_status "Restarting services..."
systemctl restart fail2ban
systemctl restart docker

# Wait for Docker to be ready
sleep 10

# Restart Odoo stack
print_status "Restarting Odoo stack..."
docker-compose down
docker-compose up -d

# Run security audit
print_status "Running security audit..."
if [ -f "./security_audit.sh" ]; then
    chmod +x ./security_audit.sh
    ./security_audit.sh
fi

# Set up first backup
print_status "Setting up first backup..."
if [ -f "./backup.sh" ]; then
    chmod +x ./backup.sh
    ./backup.sh
fi

# Final checks
print_status "Performing final checks..."
docker-compose ps
ufw status
fail2ban-client status
lynis audit system

print_status "Post-deployment hardening completed!"
print_status "Please review the security audit and backup reports"
print_status "Remember to:"
echo "1. Test SSH access before closing this session"
echo "2. Verify Odoo is accessible"
echo "3. Test SSL certificates"
echo "4. Review firewall rules"
echo "5. Configure monitoring alerts"
echo "6. Set up regular security scans"
