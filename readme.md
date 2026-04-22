# 🖥️ T.Cloud Zabbix Installer

> **Automated Zabbix 7 Installation Script for Ubuntu 24.04 — T.Cloud Gen 3**
>
> License By: Terabyte Plus and Brownyroll (BBamz Kittisak Udomsri)

---

## 📋 Requirements

| Item | Version |
|------|---------|
| OS | Ubuntu 24.04 LTS (Noble) |
| Zabbix | 7.0 LTS / 7.4 |
| Database | MySQL or PostgreSQL |
| Web Server | Apache or Nginx |

---

## 🚀 Quick Start

### 1. Install Git

```bash
apt install git -y
```

### 2. Clone Project

```bash
git clone https://github.com/terabyteplus/tcloud-zabbix.git
```

### 3. Run Installer

```bash
cd tcloud-zabbix
sudo bash ./install.sh
```

---

## 📦 Installation Menu

เลือก **Option 1** เพื่อติดตั้งทั้งหมดโดยอัตโนมัติ หรือเลือกติดตั้งทีละขั้นตอน:

```
  1)  Full Installation (All Steps)
  2)  NTP & Timezone Setup
  3)  Zabbix Server Installation
  4)  Database Setup
  5)  Start/Manage Services
  6)  SSL/HTTPS Configuration
  7)  System Update (Security Patches)
  8)  Fix Apache Path (Zabbix 7.2+)
  0)  Exit
```

### Option 1 — Full Installation

ติดตั้งทุกอย่างตามลำดับ:

1. **System Update** — อัปเดต Security Patches หรือ Full Upgrade
2. **NTP & Timezone** — ตั้ง Locale, Timezone, ติดตั้ง NTP (NIMT Thailand Servers)
3. **Zabbix Installation** — เพิ่ม Repository, ติดตั้ง Server/Frontend/Agent + Database Server
4. **Database Setup** — สร้าง Database, User, Import Schema, ตั้งค่า `zabbix_server.conf`
5. **Start Services** — เปิด `zabbix-server`, `zabbix-agent`, `apache2`

### Option 6 — SSL/HTTPS

รองรับ 3 แบบ:
- **Self-signed** — สร้าง Certificate เอง (รองรับ IP Address ใน SAN)
- **Custom Certificate** — ใช้ `.crt` / `.key` ที่มีอยู่แล้ว
- **Let's Encrypt** — ใช้ Certbot ขอ Certificate ฟรี

### Option 8 — Fix Apache Path (Zabbix 7.2+)

ตั้งแต่ Zabbix 7.2 เป็นต้นไป PHP frontend ย้ายจาก `/usr/share/zabbix` ไปเป็น `/usr/share/zabbix/ui` — สคริปต์นี้จะ fix path ให้อัตโนมัติ

---

## 📁 Project Structure

```
tcloud-zabbix/
├── install.sh                    # Main menu installer (entry point)
├── component/
│   ├── time.sh                   # NTP & Timezone setup
│   ├── zabbix.sh                 # Zabbix package installation
│   ├── database.sh               # MySQL/PostgreSQL database setup
│   ├── service.sh                # Start/stop/restart services
│   ├── ssl.sh                    # SSL/HTTPS configuration
│   └── fix-apache.sh             # Fix Apache path for Zabbix 7.2+
├── config/
│   └── ntp.conf                  # NTP config template (NIMT Thailand)
├── docs/
│   └── 01-1-Zabbix-*.docx        # Original reference guide
└── readme.md
```

---

## ⚙️ Interactive Inputs

ทุก Script จะถามค่าก่อนทำงาน — ไม่มี Hardcode:

| Script | Inputs |
|--------|--------|
| `time.sh` | Timezone, Extra NTP Server IP |
| `zabbix.sh` | Zabbix Version, Ubuntu Version, DB Type, Web Server, Components |
| `database.sh` | DB Name, User, Host, Password (with confirm), Root Password |
| `ssl.sh` | SSL Type, Domain Name, IP Addresses (SAN), Cert Validity, Org Name |
| `service.sh` | Web Server Type, Action (start/restart/stop/status) |

---

## 🔐 Default Login

หลังติดตั้งเสร็จ เข้าใช้งาน Zabbix Web UI:

```
URL:      http://<SERVER_IP>/zabbix
Username: Admin
Password: zabbix
```

> ⚠️ **กรุณาเปลี่ยนรหัสผ่านทันทีหลัง Login ครั้งแรก!**

---

## 📝 NTP Servers

ใช้ NTP Server จาก สถาบันมาตรวิทยาแห่งชาติ (NIMT) ประเทศไทย:

- `time1.nimt.or.th`
- `time2.nimt.or.th`
- `time3.nimt.or.th`
- `time4.nimt.or.th`

---

## 🔗 Reference

- [Zabbix Download](https://www.zabbix.com/download?zabbix=7.0&os_distribution=ubuntu&os_version=24.04&components=server_frontend_agent&db=mysql&ws=apache)
- [Zabbix 7.2 Upgrade Notes](https://www.zabbix.com/documentation/current/en/manual/installation/upgrade_notes_720)
- [NIMT Thailand NTP](https://www.nimt.or.th/)

---


## FIX SSL
add /ui in DocumentRoot 

```bash
 nano /etc/apache2/sites-available/000-default.conf
```

```json
<VirtualHost *:80>
    DocumentRoot "/usr/share/zabbix"
    ServerName t1099-zabbix.local
    Redirect permanent / https://t1099-zabbix.local/
</VirtualHost>
```
Change to 
```json 
<VirtualHost *:80>
    DocumentRoot "/usr/share/zabbix/ui"
    ServerName t1099-zabbix.local
    Redirect permanent / https://t1099-zabbix.local/
</VirtualHost>
```

```bash
nano /etc/apache2/sites-available/default-ssl.conf 
```
```xml
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@t1099-zabbix.local
        ServerName t1099-zabbix.local
        DocumentRoot /usr/share/zabbix/

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        SSLEngine on
        SSLCertificateFile      /etc/httpd/ssl/server.crt
        SSLCertificateKeyFile   /etc/httpd/ssl/private/private_key.key

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
    </VirtualHost>
</IfModule>
```
Change to 

```xml
<IfModule mod_ssl.c>
    <VirtualHost _default_:443>
        ServerAdmin webmaster@t1099-zabbix.local
        ServerName t1099-zabbix.local
        DocumentRoot /usr/share/zabbix/ui

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        SSLEngine on
        SSLCertificateFile      /etc/httpd/ssl/server.crt
        SSLCertificateKeyFile   /etc/httpd/ssl/private/private_key.key

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
        </Directory>
    </VirtualHost>
</IfModule>
```

## 📄 License

MIT License — Terabyte Plus
