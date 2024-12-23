FROM odoo:18

USER root

# Create necessary directories and set permissions
RUN mkdir -p /odoo-server /var/lib/odoo /mnt/extra-addons /mnt/extra-addons/moxogo18 /var/log/odoo /etc/odoo \
    && chown -R root:root /var/lib/odoo /mnt/extra-addons /var/log/odoo /etc/odoo \
    && chmod -R 777 /var/lib/odoo /mnt/extra-addons /var/log/odoo /etc/odoo

# Install system dependencies including gettext-base for envsubst
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    python3-pip \
    python3-dev \
    build-essential \
    python3-setuptools \
    python3-wheel \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    python3-psycopg2 \
    gettext-base \
    postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements.txt /tmp/requirements.txt
COPY requirements.custom.txt /tmp/requirements.custom.txt

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
    && pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.custom.txt \
    && rm -f /tmp/requirements.txt /tmp/requirements.custom.txt
