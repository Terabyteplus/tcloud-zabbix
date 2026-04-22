#!/bin/bash
#############################################
# Zabbix SSL/HTTPS Setup Script
# License By: Terabyte Plus
# Reference: Zabbix 7 on Ubuntu 24.04 Guide
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   SSL / HTTPS Configuration${NC}"
echo -e "${CYAN}   Terabyte Plus - tCloud${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ─── Check root ───
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo -s)${NC}"
    exit 1
fi

# ─── SSL Type Selection ───
echo -e "${CYAN}Select SSL Certificate Type:${NC}"
echo "  1) Self-signed certificate"
echo "  2) Custom certificate (provide your own .crt and .key files)"
echo "  3) Let's Encrypt (certbot)"
echo ""
read -p "$(echo -e ${CYAN}Select option [default: 1]:${NC} )" SSL_CHOICE
SSL_CHOICE="${SSL_CHOICE:-1}"
echo ""

# ─── Server Name ───
read -p "$(echo -e ${CYAN}Enter server domain name [e.g. zabbix.example.com]:${NC} )" SERVER_NAME
if [ -z "$SERVER_NAME" ]; then
    echo -e "${RED}[ERROR] Server domain name is required${NC}"
    exit 1
fi
echo ""

# ─── SSL Directory Setup ───
SSL_DIR="/etc/httpd/ssl"
SSL_PRIVATE_DIR="/etc/httpd/ssl/private"

mkdir -p "$SSL_DIR"
mkdir -p "$SSL_PRIVATE_DIR"
chmod 700 "$SSL_PRIVATE_DIR"
echo -e "${GREEN}[OK] SSL directories created${NC}"
echo ""

case "$SSL_CHOICE" in
    1)
        # ─── Self-Signed Certificate ───
        echo -e "${YELLOW}[INFO] Generating self-signed certificate...${NC}"

        read -p "$(echo -e ${CYAN}Certificate validity in days [default: 3650]:${NC} )" CERT_DAYS
        CERT_DAYS="${CERT_DAYS:-3650}"

        read -p "$(echo -e ${CYAN}Organization name [default: Terabyte Plus]:${NC} )" CERT_ORG
        CERT_ORG="${CERT_ORG:-T.Cloud}"

        read -p "$(echo -e ${CYAN}Country code [default: TH]:${NC} )" CERT_COUNTRY
        CERT_COUNTRY="${CERT_COUNTRY:-TH}"

        openssl req -x509 -nodes -days "$CERT_DAYS" -newkey rsa:2048 \
            -keyout "$SSL_PRIVATE_DIR/private_key.key" \
            -out "$SSL_DIR/server.crt" \
            -subj "/C=${CERT_COUNTRY}/O=${CERT_ORG}/OU=T.Cloud Gen3/CN=${SERVER_NAME}"

        CERT_FILE="$SSL_DIR/server.crt"
        KEY_FILE="$SSL_PRIVATE_DIR/private_key.key"

        echo -e "${GREEN}[OK] Self-signed certificate generated${NC}"
        ;;
    2)
        # ─── Custom Certificate ───
        echo -e "${YELLOW}[INFO] Using custom certificate...${NC}"

        read -p "$(echo -e ${CYAN}Enter path to certificate file (.crt):${NC} )" CERT_SRC
        read -p "$(echo -e ${CYAN}Enter path to private key file (.key):${NC} )" KEY_SRC

        if [ ! -f "$CERT_SRC" ]; then
            echo -e "${RED}[ERROR] Certificate file not found: $CERT_SRC${NC}"
            exit 1
        fi
        if [ ! -f "$KEY_SRC" ]; then
            echo -e "${RED}[ERROR] Key file not found: $KEY_SRC${NC}"
            exit 1
        fi

        cp "$CERT_SRC" "$SSL_DIR/"
        cp "$KEY_SRC" "$SSL_PRIVATE_DIR/"

        CERT_FILE="$SSL_DIR/$(basename $CERT_SRC)"
        KEY_FILE="$SSL_PRIVATE_DIR/$(basename $KEY_SRC)"

        echo -e "${GREEN}[OK] Certificate files copied${NC}"
        ;;
    3)
        # ─── Let's Encrypt ───
        echo -e "${YELLOW}[INFO] Setting up Let's Encrypt...${NC}"

        read -p "$(echo -e ${CYAN}Enter email for Let's Encrypt notifications:${NC} )" LE_EMAIL
        if [ -z "$LE_EMAIL" ]; then
            echo -e "${RED}[ERROR] Email is required for Let's Encrypt${NC}"
            exit 1
        fi

        apt install certbot python3-certbot-apache -y
        certbot --apache -d "$SERVER_NAME" --non-interactive --agree-tos -m "$LE_EMAIL"

        echo -e "${GREEN}[OK] Let's Encrypt certificate installed${NC}"
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   SSL Setup Complete (Let's Encrypt)!${NC}"
        echo -e "${GREEN}========================================${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""

# ─── Enable SSL Module ───
echo -e "${YELLOW}[INFO] Enabling Apache SSL module...${NC}"
a2enmod ssl
a2ensite default-ssl
echo -e "${GREEN}[OK] SSL module enabled${NC}"
echo ""

# ─── Configure Apache SSL VirtualHost ───
echo -e "${YELLOW}[INFO] Configuring Apache SSL VirtualHost...${NC}"
SSL_CONF="/etc/apache2/sites-available/default-ssl.conf"

if [ -f "$SSL_CONF" ]; then
    cp "$SSL_CONF" "${SSL_CONF}.bak"
    echo -e "${GREEN}[OK] Backed up default-ssl.conf${NC}"
fi

cat > "$SSL_CONF" <<EOF
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@${SERVER_NAME}
        ServerName ${SERVER_NAME}
        DocumentRoot /usr/share/zabbix

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        SSLEngine on
        SSLCertificateFile      ${CERT_FILE}
        SSLCertificateKeyFile   ${KEY_FILE}

        <FilesMatch "\.(cgi|shtml|phtml|php)\$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
    </VirtualHost>
</IfModule>
EOF

echo -e "${GREEN}[OK] Apache SSL VirtualHost configured${NC}"
echo ""

# ─── HTTP to HTTPS Redirect ───
read -p "$(echo -e ${CYAN}Enable HTTP to HTTPS redirect? [Y/n]:${NC} )" ENABLE_REDIRECT
ENABLE_REDIRECT="${ENABLE_REDIRECT:-Y}"

if [[ "$ENABLE_REDIRECT" =~ ^[Yy]$ ]]; then
    DEFAULT_CONF="/etc/apache2/sites-available/000-default.conf"
    cp "$DEFAULT_CONF" "${DEFAULT_CONF}.bak" 2>/dev/null || true

    cat > "$DEFAULT_CONF" <<EOF
<VirtualHost *:80>
    DocumentRoot "/usr/share/zabbix"
    ServerName ${SERVER_NAME}
    Redirect permanent / https://${SERVER_NAME}/
</VirtualHost>
EOF

    echo -e "${GREEN}[OK] HTTP to HTTPS redirect configured${NC}"
fi
echo ""

# ─── Restart Apache ───
echo -e "${YELLOW}[INFO] Restarting Apache...${NC}"
systemctl restart apache2
echo -e "${GREEN}[OK] Apache restarted${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   SSL Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Access Zabbix at: https://${SERVER_NAME}/${NC}"
echo ""
