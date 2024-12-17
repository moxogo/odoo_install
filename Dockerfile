FROM odoo:18

USER root

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Create necessary directories first
RUN set -ex; \
    mkdir -p /odoo/addons /var/log/odoo; \
    # Ensure base system is up to date
    apt-get update && apt-get upgrade -y; \
    # Install system dependencies
    apt-get install -y --no-install-recommends \
        nano \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        git \
        python3-pip \
        python3-dev \
        build-essential \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
        certbot \
        python3-certbot-nginx \
    && rm -rf /var/lib/apt/lists/*; \
    # Install PostgreSQL client packages
    apt-get update && \
    apt-get remove -y libpq5 libpq-dev postgresql-client && \
    apt-get install -y --no-install-recommends \
        libpq5=16.* \
        libpq-dev=16.* \
        postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Setup Python environment
RUN set -ex; \
    python3 -m pip install --upgrade pip setuptools wheel

# Create or update odoo user with proper permissions
RUN set -ex; \
    if ! getent group odoo > /dev/null; then groupadd -r odoo; fi; \
    if ! getent passwd odoo > /dev/null; then \
        useradd -r -g odoo -d /odoo -s /sbin/nologin odoo; \
    else \
        usermod -d /odoo odoo; \
    fi; \
    chown -R odoo:odoo /odoo /var/log/odoo

# Copy and set permissions for requirements files
COPY --chown=odoo:odoo requirements.txt requirements.custom.txt /tmp/

# Install Python dependencies as root (to avoid permission issues)
RUN set -ex; \
    pip3 install --no-cache-dir --break-system-packages psycopg2-binary; \
    pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt; \
    pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.custom.txt; \
    # Verify installations
    python3 -c "import psycopg2" && \
    # Clean up
    rm -rf /root/.cache /tmp/pip* /tmp/*.txt

# Final permission check and setup
RUN set -ex; \
    chown -R odoo:odoo /odoo /var/log/odoo; \
    chmod -R 755 /odoo; \
    chmod -R 777 /var/log/odoo

# Switch to odoo user for runtime
USER odoo

# Verify the environment is properly set up
RUN set -ex; \
    python3 -c "import psycopg2; print('PostgreSQL client installation verified')" && \
    echo "Odoo environment setup complete"
