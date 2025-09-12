# Airgap Tool: Self-Signed Certificate Generation

This repository includes a script to generate a self-signed root CA certificate with Subject Alternative Names (SANs) for all FQDNs used in the airgap tool setup.  
The certificate can be installed into the system trust store and used for internal HTTPS services (Devpi, Harbor, GitLab, repo-server etc.).

---

## ▶️ Usage

Run the script:

```bash
sudo ./generate-selfsigned-cert.sh
```

### The script will prompt for:

- **Common Name (CN)** (default: `*.td2.com`)
- **Validity in days** (default: `365`)
- **Subject Alternative Names (SANs)** — add as many DNS entries as needed, defaults are included:
  - `*.td2.com`
  - `pypi.td2.com`
  - `harbor.td2.com`
  - `repo-server.td2.com`
- **Custom paths for key and certificate** (optional)

### Example interactive run

```bash
$ sudo ./generate-selfsigned-cert.sh
Enter Common Name (CN) [*.td2.com]:
Validity in days [365]:
Default SANs:
  - *.td2.com
  - pypi.td2.com
  - harbor.td2.com
  - repo-server.td2.com
Use defaults as starting list? [Y/n]: Y
Add SAN DNS entry (leave empty to finish): gitlab.td2.com
Add SAN DNS entry (leave empty to finish):
Path to save certificate [/etc/ssl/certs/rootCA.crt]: /opt/certs/myCA.crt
Path to save key [/etc/ssl/private/rootCA.key]: /opt/certs/myCA.key
➡️  Generated OpenSSL config at /tmp/tmp.XXXXXX/san.cnf
✅ Certificate created:
  Key : /opt/certs/myCA.key
  Cert: /opt/certs/myCA.crt
```

### Generated OpenSSL Config

The script generates a temporary OpenSSL config (san.cnf) like this:
```bash
[ req ]
default_bits       = 4096
prompt             = no
default_md         = sha256
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
CN = *.td2.com

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = *.td2.com
DNS.2 = pypi.td2.com
DNS.3 = harbor.td2.com
DNS.5 = repo-server.td2.com
DNS.6 = gitlab.td2.com
```
