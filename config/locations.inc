# Global proxy settings
proxy_ignore_headers "X-Accel-Expires" "Expires" "Cache-Control" "Set-Cookie" "Server";
proxy_hide_header Date;
proxy_hide_header Server;
proxy_hide_header X-Powered-By;
proxy_hide_header X-Runtime;
proxy_hide_header X-Frame-Options;

# Main location block
location / {
    proxy_pass http://odoo;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_buffering off;
}

# Websocket support
location /websocket {
    proxy_pass http://odoochat;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
}

# Longpolling support
location /longpolling {
    proxy_pass http://odoochat;
    proxy_http_version 1.1;
    proxy_buffering off;
}

# Static files
location ~* /web/static/ {
    proxy_pass http://odoo;
    proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
    proxy_cache_valid 200 60m;
    expires 864000;
    add_header Cache-Control "public, no-transform";
}

# Compression settings
gzip on;
gzip_types text/plain text/css application/json application/javascript;
gzip_min_length 1000;
gzip_comp_level 6;
gzip_vary on;
