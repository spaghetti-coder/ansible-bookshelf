# Caddy container specifics

## Using cert files for TLS

See referenced files in the role.

```yaml
# caddy variables

# ...
caddy_modules:              # <- Not needed for cert files
caddy_cert_bundles:
    # 
    # The demo bundle is generated with:
    # 
    #   openssl req -x509 -days 3650 -noenc -keyout /dev/stdout -out /dev/stdout \
    #     -subj "/CN=test.local" \
    #     -addext "subjectAltName=DNS:test.local,DNS:*.test.local" \
    #   | base64 >./demo1.bundle.pem
    # 
    # NOTE: It's base64 encoded to avoid github security warnings for exposed key file
    # 
  - text: "{{ lookup('file', 'demo1.bundle.pem') | b64decode }}"
    name: test.local.pem    # <- Will land in /etc/ssl/private/test.local.pem
caddy_caddyfile: "{{ lookup('file', 'demo1.Caddyfile') }}"
# ...
```

## Using some dns module (deSEC as example)

```yaml
# caddy variables

# ...
caddy_modules: 
  - github.com/caddy-dns/desec
caddy_cert_bundles:           # <- Not needed for cert files
caddy_caddyfile: "{{ lookup('file', 'demo2.Caddyfile') }}"
caddy_extra_env:
  DESEC_BASE=demo.dedyn.io    # <- Demo base domain
caddy_secrets_env:
  DESEC_TOKEN=123changeme456  # <- Of course it's a dummy, replace with a real one
# ...
```
