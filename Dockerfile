FROM odoo:18

USER root

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# Create necessary directories and set permissions
RUN mkdir -p /var/lib/odoo /mnt/extra-addons /mnt/extra-addons/moxogo18 /var/log/odoo \
    && chown -R odoo:odoo /var/lib/odoo /mnt/extra-addons /var/log/odoo \
    && chmod -R 755 /mnt/extra-addons /var/log/odoo

# Install system dependencies
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
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-client-16 \
    && rm -rf /var/lib/apt/lists/*

# Switch to odoo user for runtime
USER odoo

WORKDIR /var/lib/odoo

CMD ["odoo"]
