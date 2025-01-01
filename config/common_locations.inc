# Security headers
add_header Strict-Transport-Security "max-age=63072000" always;
add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Content-Type-Options "nosniff";

# Websocket
location /websocket {
    proxy_pass http://odoochat;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}

# Longpolling
location /longpolling {
    proxy_pass http://odoochat;
}

# Static files
location ~* /web/static/ {
    proxy_pass http://odoo;
    proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
    proxy_cache_valid 200 60m;
    expires 864000;
}

# Main location
location / {
    proxy_pass http://odoo;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
}

# Compression
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
gzip_min_length 1000;
