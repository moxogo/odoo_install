FROM odoo:18

USER root

# Install system dependencies
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
        postgresql-client \
        libpq-dev \
        libldap2-dev \
        libsasl2-dev \
        libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements.txt /tmp/requirements.txt
COPY requirements.custom.txt /tmp/requirements.custom.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed psycopg2-binary && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.custom.txt

USER odoo
