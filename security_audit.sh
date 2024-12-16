#!/bin/bash

# Function to print status messages
print_status() {
    echo -e "\n==> $1"
}

# Function to print results
print_result() {
    if [ $? -eq 0 ]; then
        echo -e "[\e[32m OK \e[0m] $1"
    else
        echo -e "[\e[31m FAIL \e[0m] $1"
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_status "Please run as root"
    exit 1
fi

# Create audit directory
timestamp=$(date +%Y%m%d_%H%M%S)
audit_dir="security_audit_${timestamp}"
mkdir -p "$audit_dir"

print_status "Starting Security Audit..."

# System Information
print_status "Gathering System Information..."
{
    echo "=== System Information ==="
    uname -a
    lsb_release -a 2>/dev/null
    echo "=== CPU Information ==="
    lscpu
    echo "=== Memory Information ==="
    free -h
    echo "=== Disk Usage ==="
    df -h
} > "$audit_dir/system_info.txt"
print_result "System information gathered"

# Security Packages
print_status "Checking Security Packages..."
{
    echo "=== Installed Security Packages ==="
    dpkg -l | grep -E "fail2ban|ufw|apparmor|clamav|auditd|aide|rkhunter|chkrootkit"
} > "$audit_dir/security_packages.txt"
print_result "Security packages checked"

# Firewall Status
print_status "Checking Firewall Status..."
{
    echo "=== UFW Status ==="
    ufw status verbose
    echo -e "\n=== IPTables Rules ==="
    iptables -L -n -v
} > "$audit_dir/firewall_status.txt"
print_result "Firewall status checked"

# Network Security
print_status "Checking Network Security..."
{
    echo "=== Open Ports ==="
    netstat -tuln
    echo -e "\n=== Active Connections ==="
    netstat -tan | grep ESTABLISHED
    echo -e "\n=== Network Interfaces ==="
    ip a
} > "$audit_dir/network_security.txt"
print_result "Network security checked"

# Docker Security
print_status "Checking Docker Security..."
{
    echo "=== Docker Version ==="
    docker version
    echo -e "\n=== Docker Info ==="
    docker info
    echo -e "\n=== Docker Container Security ==="
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
    echo -e "\n=== Docker Network Security ==="
    docker network ls
    for network in $(docker network ls --format "{{.Name}}"); do
        echo -e "\nNetwork: $network"
        docker network inspect "$network"
    done
} > "$audit_dir/docker_security.txt"
print_result "Docker security checked"

# SSL/TLS Configuration
print_status "Checking SSL/TLS Configuration..."
{
    echo "=== SSL Certificates ==="
    ls -l /etc/letsencrypt/live/
    echo -e "\n=== SSL Configuration ==="
    if [ -f "./nginx/conf.d/odoo.conf.template" ]; then
        grep -A 20 "ssl_" ./nginx/conf.d/odoo.conf.template
    fi
} > "$audit_dir/ssl_config.txt"
print_result "SSL/TLS configuration checked"

# File Permissions
print_status "Checking Critical File Permissions..."
{
    echo "=== Critical File Permissions ==="
    ls -la /etc/passwd /etc/shadow /etc/group /etc/gshadow
    echo -e "\n=== SUID Files ==="
    find / -type f -perm -4000 2>/dev/null
    echo -e "\n=== World-Writable Files ==="
    find / -type f -perm -2 ! -path "/proc/*" ! -path "/sys/*" 2>/dev/null
} > "$audit_dir/file_permissions.txt"
print_result "File permissions checked"

# User Security
print_status "Checking User Security..."
{
    echo "=== User List ==="
    cat /etc/passwd
    echo -e "\n=== Sudo Users ==="
    grep -Po '^sudo.+:\K.*$' /etc/group
    echo -e "\n=== Login History ==="
    last | head -n 20
} > "$audit_dir/user_security.txt"
print_result "User security checked"

# Service Status
print_status "Checking Service Status..."
{
    echo "=== System Services ==="
    systemctl list-units --type=service --state=active
    echo -e "\n=== Failed Services ==="
    systemctl --failed
} > "$audit_dir/service_status.txt"
print_result "Service status checked"

# Odoo Security
print_status "Checking Odoo Security..."
{
    echo "=== Odoo Container Status ==="
    docker-compose ps odoo
    echo -e "\n=== Odoo Container Logs (Last 100 lines) ==="
    docker-compose logs --tail=100 odoo
    echo -e "\n=== Odoo Configuration ==="
    if [ -f "./config/odoo.conf" ]; then
        grep -v "^#" ./config/odoo.conf | grep -v "^$"
    fi
} > "$audit_dir/odoo_security.txt"
print_result "Odoo security checked"

# Generate Summary Report
print_status "Generating Summary Report..."
{
    echo "Security Audit Summary Report"
    echo "Generated on: $(date)"
    echo -e "\nSystem Status:"
    echo "- Firewall: $(ufw status | grep -q "active" && echo "Active" || echo "Inactive")"
    echo "- Fail2ban: $(systemctl is-active fail2ban)"
    echo "- AppArmor: $(systemctl is-active apparmor)"
    echo "- Docker: $(systemctl is-active docker)"
    echo "- Odoo Container: $(docker-compose ps odoo | grep -q "Up" && echo "Running" || echo "Stopped")"
    
    echo -e "\nSecurity Recommendations:"
    # Firewall
    if ! ufw status | grep -q "active"; then
        echo "- Enable UFW firewall"
    fi
    # SSH
    if grep -q "PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        echo "- Disable root SSH login"
    fi
    # Docker
    if docker info 2>/dev/null | grep -q "live-restore: false"; then
        echo "- Enable Docker live-restore"
    fi
    # SSL
    if [ ! -d "./certbot/conf/live" ]; then
        echo "- SSL certificates not found"
    fi
} > "$audit_dir/summary_report.txt"
print_result "Summary report generated"

# Create compressed archive
print_status "Creating audit archive..."
tar -czf "security_audit_${timestamp}.tar.gz" "$audit_dir"
rm -rf "$audit_dir"
print_result "Audit archive created: security_audit_${timestamp}.tar.gz"

print_status "Security audit completed! Please review security_audit_${timestamp}.tar.gz"
