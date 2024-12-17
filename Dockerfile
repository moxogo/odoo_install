FROM odoo:18

USER root

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Create necessary directories and set permissions
RUN mkdir -p /var/lib/odoo /mnt/extra-addons /mnt/extra-addons/moxogo18 /var/log/odoo /etc/odoo \
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
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/lib/odoo

# Copy and set entrypoint script
COPY ./config/entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config", "/etc/odoo/odoo.conf"]
