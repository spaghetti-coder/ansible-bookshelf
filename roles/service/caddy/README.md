# Caddy container specifics

## Using cert files fot TLS

See referenced files in the role.

```yaml
# caddy variables

# ...
caddy_modules: []           # <- Not needed for cert files
caddy_cert_bundles:
    # 
    # The demo bundle is generated with:
    #   openssl req -x509 -days 3650 -noenc -keyout /dev/stdout -out /dev/stdout \
    #     -subj "/CN=test.local" \
    #     -addext "subjectAltName=DNS:test.local,DNS:*.test.local" \
    #   | base64 >./demo.bundle.pem
  - text: "{{ lookup('file', 'demo.bundle.pem') | b64decode }}"
    name: test.local.pem    # <- Will land in /etc/ssl/private/test.local.pem
caddy_caddyfile: "{{ lookup('file', 'demo.Caddyfile') }}"
# ...
```
