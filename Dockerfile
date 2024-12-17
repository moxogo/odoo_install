FROM odoo:18

USER root

# Create necessary directories first
RUN mkdir -p /odoo /odoo /var/log/odoo

# Create or update odoo user
RUN if ! getent group odoo > /dev/null; then \
        groupadd -r odoo; \
    fi && \
    if ! getent passwd odoo > /dev/null; then \
        useradd -r -g odoo -d /odoo -s /sbin/nologin odoo; \
    else \
        usermod -d /odoo odoo; \
    fi && \
    chown -R odoo:odoo /odoo  /var/log/odoo

# Install system dependencies (without PostgreSQL packages first)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nano \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        git \
        python3-pip \
        certbot \
        python3-certbot-nginx \
        python3-dev \
        build-essential \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client packages
RUN apt-get update && \
    apt-get remove -y libpq5 libpq-dev postgresql-client && \
    apt-get install -y --no-install-recommends \
        libpq5=16.* \
        libpq-dev=16.* \
        postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements.txt /tmp/requirements.txt
COPY requirements.custom.txt /tmp/requirements.custom.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed psycopg2-binary && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.custom.txt && \
    chown odoo:odoo /tmp/requirements.txt /tmp/requirements.custom.txt

# Switch to odoo user
USER odoo
