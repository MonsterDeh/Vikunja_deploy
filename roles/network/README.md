# network

Creates the external Docker bridge network used by the Vikunja application
and deploys an Nginx container as its HTTP/HTTPS reverse proxy.

By default, the role generates a self-signed TLS certificate and private key
under `nginx_ssl_host_dir`. They are mounted read-only and referenced by
`templates/nginx_config.txt.j2`.

Set `nginx_ssl_generate_self_signed: false` when a trusted certificate is
provisioned by another role or certificate manager.
