#!/bin/bash

CONF_NAME="mask_proxy"
NGINX_CONF="/etc/nginx/sites-available/$CONF_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$CONF_NAME"
SSL_DIR="/etc/nginx/ssl/$CONF_NAME"
ACCESS_LOG="/var/log/nginx/${CONF_NAME}_access.log"
ERROR_LOG="/var/log/nginx/${CONF_NAME}_error.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

parse_url() {
python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse

url = sys.argv[1].strip()
u = urlparse(url)

scheme = u.scheme or "https"
host = u.hostname or ""
port = u.port

if not port:
    port = 443 if scheme == "https" else 80

print(scheme)
print(host)
print(port)
PY
}

install_proxy() {
    echo ""
    echo "🌐 Esasy domeni ýaz"
    echo "Mysal:"
    echo "https://gcp.escglobalworld.ru"
    echo "https://gcp.escglobalworld.ru:8443"
    echo "http://gcp.escglobalworld.ru"
    read -rp "Domen: " FRONT_URL

    FRONT_PARSED="$(parse_url "$FRONT_URL")"
    FRONT_SCHEME="$(echo "$FRONT_PARSED" | sed -n '1p')"
    FRONT_HOST="$(echo "$FRONT_PARSED" | sed -n '2p')"
    FRONT_PORT="$(echo "$FRONT_PARSED" | sed -n '3p')"

    if [ -z "$FRONT_HOST" ]; then
        echo "❌ Domen ýalňyş"
        return
    fi

    echo ""
    echo "🎯 Maksat domeni ýaz"
    echo "Mysal:"
    echo "https://nasa.nz5.org"
    echo "https://nasa.nz5.org:800"
    echo "http://nasa.nz5.org:800"
    read -rp "Maksat: " TARGET_URL

    if [ -z "$TARGET_URL" ]; then
        echo "❌ Maksat domen boş bolup bilmez"
        return
    fi

    apt update
    apt install -y nginx python3

    rm -f /etc/nginx/sites-enabled/default
    mkdir -p /var/log/nginx

    if [ "$FRONT_SCHEME" = "https" ]; then
        echo ""
        echo "🔐 HTTPS saýlandy"

        if [ -f "$SCRIPT_DIR/fullchain.pem" ] && [ -f "$SCRIPT_DIR/key.pem" ]; then
            FULLCHAIN="$SCRIPT_DIR/fullchain.pem"
            PRIVKEY="$SCRIPT_DIR/key.pem"
            echo "✅ Sertifikatlar script bukjasynda tapyldy"
        else
            echo "⚠️ fullchain.pem ýa-da key.pem script bukjasynda tapylmady"
            read -rp "fullchain.pem ýoly: " FULLCHAIN
            read -rp "key.pem ýoly: " PRIVKEY
        fi

        if [ ! -f "$FULLCHAIN" ]; then
            echo "❌ fullchain.pem tapylmady"
            return
        fi

        if [ ! -f "$PRIVKEY" ]; then
            echo "❌ key.pem tapylmady"
            return
        fi

        mkdir -p "$SSL_DIR"
        cp "$FULLCHAIN" "$SSL_DIR/fullchain.pem"
        cp "$PRIVKEY" "$SSL_DIR/key.pem"

        chmod 644 "$SSL_DIR/fullchain.pem"
        chmod 600 "$SSL_DIR/key.pem"

        LISTEN_LINE="listen $FRONT_PORT ssl;"
        SSL_LINES="
    ssl_certificate $SSL_DIR/fullchain.pem;
    ssl_certificate_key $SSL_DIR/key.pem;"
    else
        LISTEN_LINE="listen $FRONT_PORT;"
        SSL_LINES=""
    fi

    cat > "$NGINX_CONF" <<NGINX
server {
    $LISTEN_LINE
    server_name $FRONT_HOST;
$SSL_LINES

    access_log $ACCESS_LOG;
    error_log $ERROR_LOG;

    location = / {
        default_type text/plain;
        return 200 "Bu URL VPNler üçindir\\n";
    }

    location / {
        proxy_pass $TARGET_URL;
        proxy_ssl_server_name on;

        proxy_set_header Host \$proxy_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_redirect off;
    }
}
NGINX

    ln -sf "$NGINX_CONF" "$NGINX_LINK"

    echo ""
    echo "🔎 Nginx barlanýar..."
    if ! nginx -t; then
        echo "❌ Nginx sazlamasynda näsazlyk bar"
        return
    fi

    systemctl enable nginx >/dev/null 2>&1

    if systemctl restart nginx; then
        echo ""
        echo "✅ Gurnama tamamlandy"
    else
        echo ""
        echo "❌ Nginx başlamady"
        systemctl status nginx --no-pager
        return
    fi
}

show_logs() {
    echo ""
    echo "📜 Log görkezilýär. Çykmak üçin CTRL+C"
    touch "$ACCESS_LOG" "$ERROR_LOG"
    tail -f "$ERROR_LOG" "$ACCESS_LOG"
}

remove_proxy() {
    echo ""
    echo "🗑 Proxy aýrylýar..."

    rm -f "$NGINX_LINK"
    rm -f "$NGINX_CONF"
    rm -rf "$SSL_DIR"
    rm -f "$ACCESS_LOG" "$ERROR_LOG"

    if nginx -t; then
        systemctl restart nginx
        echo "✅ Hemmesi aýryldy"
    else
        echo "⚠️ Nginx sazlamasynda başga näsazlyk bar"
    fi
}

while true
do
    echo ""
    echo "=============================="
    echo " NGINX Mask Proxy Menýu"
    echo "=============================="
    echo "1. Gurnama et"
    echo "2. Log görkez"
    echo "3. Aýyr"
    echo "0. Çyk"
    echo "=============================="
    read -rp "Saýla: " CHOICE

    case "$CHOICE" in
        1) install_proxy ;;
        2) show_logs ;;
        3) remove_proxy ;;
        0) exit 0 ;;
        *) echo "❌ Ýalňyş saýlaw" ;;
    esac
done
