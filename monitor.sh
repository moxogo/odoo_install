#!/bin/bash

# Load environment variables
set -a
source .env
set +a

# Function to print status messages
print_status() {
    echo "==> $1"
}

# Function to send notifications (customize as needed)
send_notification() {
    local subject="$1"
    local message="$2"
    local priority="$3"
    
    # Example: Send email
    echo "$message" | mail -s "[${priority}] $subject" "${ADMIN_EMAIL:-root}"
    
    # Add other notification methods here (Slack, Discord, etc.)
}

# Function to check container health
check_container_health() {
    local container="$1"
    local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
    
    if [ "$status" != "healthy" ]; then
        send_notification "Container Health Alert" "Container $container is $status" "HIGH"
        return 1
    fi
    return 0
}

# Function to check disk usage
check_disk_usage() {
    local threshold=80
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt "$threshold" ]; then
        send_notification "Disk Usage Alert" "Disk usage is at ${usage}%" "HIGH"
        return 1
    fi
    return 0
}

# Function to check memory usage
check_memory_usage() {
    local threshold=90
    local usage=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
    
    if [ "$usage" -gt "$threshold" ]; then
        send_notification "Memory Usage Alert" "Memory usage is at ${usage}%" "HIGH"
        return 1
    fi
    return 0
}

# Function to check SSL certificate expiry
check_ssl_expiry() {
    local domain="$NGINX_DOMAIN"
    local days_warning=30
    
    if [ -f "./certbot/conf/live/$domain/cert.pem" ]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "./certbot/conf/live/$domain/cert.pem" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local now_epoch=$(date +%s)
        local days_left=$(( ($expiry_epoch - $now_epoch) / 86400 ))
        
        if [ "$days_left" -lt "$days_warning" ]; then
            send_notification "SSL Certificate Alert" "SSL certificate for $domain expires in $days_left days" "HIGH"
            return 1
        fi
    fi
    return 0
}

# Function to check failed login attempts
check_failed_logins() {
    local threshold=10
    local count=$(grep -c "Unauthorized login attempt" /var/lib/docker/containers/*/*.log)
    
    if [ "$count" -gt "$threshold" ]; then
        send_notification "Security Alert" "$count failed login attempts detected" "HIGH"
        return 1
    fi
    return 0
}

# Function to check backup status
check_backup_status() {
    local backup_dir="/var/backups/odoo"
    local max_age=86400  # 24 hours in seconds
    
    if [ -d "$backup_dir" ]; then
        local latest_backup=$(find "$backup_dir" -name "*.tar.gz.gpg" -type f -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2)
        if [ -n "$latest_backup" ]; then
            local file_age=$(($(date +%s) - $(date +%s -r "$latest_backup")))
            if [ "$file_age" -gt "$max_age" ]; then
                send_notification "Backup Alert" "Latest backup is older than 24 hours" "HIGH"
                return 1
            fi
        else
            send_notification "Backup Alert" "No backup files found" "HIGH"
            return 1
        fi
    fi
    return 0
}

# Function to check system load
check_system_load() {
    local threshold=4
    local load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | tr -d ' ')
    
    if [ "$(echo "$load > $threshold" | bc)" -eq 1 ]; then
        send_notification "System Load Alert" "System load is $load" "HIGH"
        return 1
    fi
    return 0
}

# Function to check Docker logs for errors
check_docker_logs() {
    local error_count=$(docker-compose logs --tail=1000 | grep -iE "error|exception|fatal" | wc -l)
    local threshold=10
    
    if [ "$error_count" -gt "$threshold" ]; then
        send_notification "Docker Logs Alert" "$error_count errors found in logs" "HIGH"
        return 1
    fi
    return 0
}

# Main monitoring loop
while true; do
    print_status "Running health checks..."
    
    # Run all checks
    check_container_health "odoo18"
    check_container_health "odoo18_db"
    check_container_health "odoo18_nginx"
    check_disk_usage
    check_memory_usage
    check_ssl_expiry
    check_failed_logins
    check_backup_status
    check_system_load
    check_docker_logs
    
    # Generate health report
    report_file="/var/log/odoo_health_$(date +%Y%m%d).log"
    {
        echo "Health Check Report - $(date)"
        echo "=========================="
        echo "Container Status:"
        docker-compose ps
        echo -e "\nDisk Usage:"
        df -h
        echo -e "\nMemory Usage:"
        free -h
        echo -e "\nSystem Load:"
        uptime
        echo -e "\nFail2Ban Status:"
        fail2ban-client status
        echo -e "\nDocker Stats:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    } >> "$report_file"
    
    # Rotate logs if needed
    find /var/log -name "odoo_health_*.log" -type f -mtime +7 -delete
    
    # Wait before next check
    sleep 300  # 5 minutes
done
