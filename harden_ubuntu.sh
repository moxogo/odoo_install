#!/bin/bash

echo "Starting Ubuntu Hardening Script..."

# Update and Upgrade System
echo "Updating and upgrading system packages..."
sudo apt update -y
sudo apt upgrade -y
sudo apt dist-upgrade -y

# Remove Unnecessary Packages
echo "Removing unnecessary packages..."
sudo apt autoremove -y

# Install Security Tools
echo "Installing necessary security tools..."
sudo apt install -y fail2ban ufw apparmor clamav clamav-daemon unattended-upgrades

# Configure Unattended Upgrades
echo "Configuring unattended upgrades..."
sudo cp /etc/apt/apt.conf.d/20auto-upgrades /etc/apt/apt.conf.d/20auto-upgrades.bak
echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades

# Enable and Configure UFW
echo "Enabling and configuring UFW..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp  # Allow SSH
sudo ufw allow 80/tcp  # Allow HTTP
sudo ufw allow 443/tcp # Allow HTTPS
sudo ufw enable

# Enable and Configure AppArmor
echo "Enabling and configuring AppArmor..."
sudo systemctl enable apparmor
sudo systemctl start apparmor

# Install and Configure Fail2Ban
echo "Configuring Fail2Ban..."
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure SSH
echo "Hardening SSH..."
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Install and Configure ClamAV
echo "Configuring ClamAV..."
sudo systemctl enable clamav-daemon
sudo systemctl start clamav-daemon
sudo freshclam
sudo clamscan -r / --bell -i

# Hardening File Permissions
echo "Hardening file permissions..."
sudo chmod 700 /home/*
sudo chmod 750 /var/log
sudo chmod 640 /etc/sudoers
sudo chmod 640 /etc/sudoers.d/*

# Verify Cron Jobs
echo "Verifying cron jobs..."
sudo chmod 600 /etc/crontab
sudo chmod 600 /etc/cron.hourly
sudo chmod 600 /etc/cron.daily
sudo chmod 600 /etc/cron.weekly
sudo chmod 600 /etc/cron.monthly
sudo chmod 600 /etc/cron.d
sudo chmod 600 /etc/cron.deny
sudo chmod 644 /etc/cron.allow

# Disable Unnecessary Services
echo "Disabling unnecessary services..."
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon

# Set Up Regular Backups
echo "Setting up regular backups..."
sudo apt install -y debconf-utils
sudo debconf-set-selections <<< "debconf debconf/frontend select noninteractive"
sudo apt install -y backupninja
sudo sed -i 's|# - day:|  - day:|' /etc/backupninja/nightly.conf

# Enable Automatic Security Updates
echo "Enabling automatic security updates..."
sudo sed -i 's|"\${distro_id}:${distro_codename}";|"\${distro_id}:${distro_codename}-security";|' /etc/apt/apt.conf.d/50unattended-upgrades

# Disable Root Login via Console
echo "Disabling root login via console..."
sudo passwd -l root

# Install and Configure Firewall GUI (Optional)
echo "Optionally installing GUFW for GUI management..."
sudo apt install -y gufw

echo "Ubuntu Hardening Script Completed."