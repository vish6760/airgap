# Devpi Private PyPI Setup Script

This repository contains a Bash script to install and configure a **private Python package index (PyPI)** using [devpi](https://devpi.net).  
It automates the setup of devpi, systemd service, and nginx reverse proxy with SSL support.

---

## ✨ Features

- ✅ Interactive prompts for **FQDN, user, data directory, and venv directory**
- ✅ **Idempotent** – safe to re-run for upgrades or reconfiguration
- ✅ Error handling with logs (`/var/log/setup-devpi.log`)
- ✅ Systemd integration for persistent service management
- ✅ Nginx reverse proxy with HTTP → HTTPS redirection

---

## 📌 What the Script Does

This will:

1. Install required packages  
2. Create a dedicated `devpi` user  
3. Set up a Python virtual environment for Devpi  
4. Initialize the Devpi server  
5. Configure **systemd** service `devpi.service`  
6. Configure **Nginx reverse proxy with HTTPS**

---

## 🔧 Requirements

- Ubuntu/Debian based Linux (tested on **Ubuntu 22.04** and **24.04**)  
- Root privileges (`sudo`)  
- SSL certificate and key placed in:
  - `/etc/ssl/certs/rootCA.crt`
  - `/etc/ssl/private/rootCA.key`

NOTE - Self signed certificate could be use for testing.
---

## 🚀 Installation

Clone the repo and make the script executable:

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
chmod +x setup-devpi.sh


### ▶️  Usage

Run the script:
```bash
./setup-devpi.sh
```
The script will prompt you for:
FQDN (default: pypi.td2.com)
System user to run devpi (default: devpi)
Devpi data directory (default: /srv/devpi)
Python virtualenv directory (default: /srv/venv)
```bash
Enter FQDN [pypi.td2.com]: mypypi.example.com
Enter devpi system user [devpi]: devpiuser
Enter Devpi data directory [/srv/devpi]: /opt/devpi
Enter Python virtualenv directory [/srv/venv]: /opt/venv
```

---

### 🛠 Managing Devpi Service

Check service status:
```bash
sudo systemctl status devpi
```

View logs:
```bash
sudo journalctl -u devpi -f
```

### 📦 Configure Devpi Indexes

1. Set up CA certificates:

```bash
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/rootCA.crt
export SSL_CERT_FILE=/etc/ssl/certs/rootCA.crt
```

2. Use the root index:
```bash
devpi use https://pypi.td2.com/root/pypi
devpi login root --password=''
```

3. Configure mirror to upstream PyPI:
```bash
devpi index -c pypi mirror_url=https://pypi.org/simple
devpi index -l
```

Example output:
```bash
https://pypi.td2.com/root/pypi:
  type=mirror
  volatile=False
  mirror_url=https://pypi.org/simple/
  mirror_web_url_fmt=https://pypi.org/project/{name}/
  title=PyPI
```

4. Create a custom index:
```bash
devpi index -c myindex bases=/root/pypi
devpi index root/myindex
```

---

### 🖥 Client Configuration

Update ~/.pip/pip.conf (Linux/macOS)
```bash
[global]
index-url = https://pypi.td2.com/root/myindex/
trusted-host = pypi.td2.com
timeout = 60
```

### ✅ Testing

Verify access:
```bash
curl -v https://pypi.td2.com/
```
If successful, all clients can now fetch Python packages via your private PyPI mirror.

####  📝 Notes

Running the script multiple times will not overwrite existing devpi data/config unless needed.
Update your SSL cert/key paths in the nginx section if different from defaults.
