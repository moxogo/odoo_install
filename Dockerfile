FROM odoo:18

USER root

# Install initial dependencies
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    gnupg

# Add PostgreSQL repository
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgres-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgres-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nano \
    software-properties-common \
    git \
    python3-pip \
    certbot \
    python3-certbot-nginx \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libpq5 \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements.txt /tmp/requirements.txt
COPY requirements.custom.txt /tmp/requirements.custom.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages --ignore-installed psycopg2-binary && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/requirements.custom.txt

USER odoo
