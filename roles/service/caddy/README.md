# Caddy

## Using cert files for TLS

See referenced files in the role.

```yaml
# caddy variables

# ...
caddy_modules:              # <- Not needed for cert files
caddy_cert_bundles:
  - text: "{{ lookup('file', 'demo1.bundle.pem.b64') | b64decode }}"
    name: test.local.pem    # <- Will land in /etc/ssl/private/test.local.pem
caddy_caddyfile: "{{ lookup('file', 'demo1.Caddyfile') }}"
# ...
```

Certificate is base64 encoded to avoid github security warnings for exposed key file. The command to generate:

```sh
openssl req -x509 -days 3650 -noenc -keyout /dev/stdout -out /dev/stdout \
  -subj "/CN=test.local" \
  -addext "subjectAltName=DNS:test.local,DNS:*.test.local" \
| base64 >./demo1.bundle.pem
```

## Using some dns module (deSEC as example)

```yaml
# variables

# ...
caddy_modules:                  # <- https://caddyserver.com/docs/modules/ 
  - github.com/caddy-dns/desec  # <- https://caddyserver.com/docs/modules/dns.providers.desec
caddy_cert_bundles:             # <- Cert files not needed, will be generated
caddy_caddyfile: "{{ lookup('file', 'demo2.Caddyfile') }}"
caddy_extra_env:
  DESEC_BASE=demo.dedyn.io      # <- Demo base domain
caddy_secrets_env:
  DESEC_TOKEN=123changeme456    # <- Of course it's a dummy, replace with yours
# ...
```

### Plus [nginx-proxy](./../nginx-proxy)

```yaml
# variables

# ...
# Caddy config same as above, excluding
caddy_caddyfile: "{{ lookup('file', 'demo3.Caddyfile') }}"
# ...
nginx_proxy_enabled: true
nginx_proxy_ports:          # <-> Empty, external ports are not required
# ...
```

## PVE SPICE

Dog slow, by the way... Nginx is a better alternative

```yaml
# variables

# ...
caddy_modules:
  - github.com/mholt/caddy-l4
caddy_cert_bundles:
  - text: "{{ lookup('file', 'demo1.bundle.pem.b64') | b64decode }}"
    name: test.local.pem
caddy_caddyfile: "{{ lookup('file', 'demo4.Caddyfile') }}"
caddy_ports:
  - 80:80
  - 443:443
  - 3128:3128                 # <- SPICE port
caddy_extra_env:
  PVE_HOST=pve.test.local
  PVE_IP=192.168.1.10
# ...
```
