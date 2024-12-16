FROM odoo:18

USER root

# Add PostgreSQL repository and install system dependencies
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list' && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    apt-get update && \
    apt-get remove -y libpq5 && \
    apt-get install -y \
    nano \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git \
    python3-pip \
    certbot \
    python3-certbot-nginx \
    libpq5=16.* \
    libpq-dev=16.* \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements.txt /tmp/requirements.txt
COPY requirements.custom.txt /tmp/requirements.custom.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed psycopg2-binary && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.custom.txt

USER odoo
