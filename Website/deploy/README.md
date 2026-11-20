# Website deployment

The existing Glasscode host serves this site from `/var/www/lemmings`.
Use the `release/ultimate-lemmix` branch. Keep the website source committed.

## HTTPS setup

1. Point the DNS-only `lemmings` A record to `194.195.248.217`.
2. Install `http-bootstrap.conf` as the dedicated Nginx site configuration.
3. Check Nginx configuration, then reload Nginx.
4. Use the existing Certbot account to request a webroot certificate for `lemmings.glasscode.academy`.
5. Use `/var/www/letsencrypt` as the ACME webroot.
6. Verify the existing `/etc/letsencrypt/renewal-hooks/post/nginx-reload.sh` hook.
7. Verify a certificate-specific renewal dry run.

The host's existing hook validates Nginx configuration before reloading the
server. Keep this shared hook intact. Do not add a duplicate reload hook.

## Publish and verify

1. Run `bash Website/deploy/publish.sh` from the repository.
2. Verify the public HTTPS routes, deployed hashes, canonical URLs and error responses.
3. Check the rendered pages and keyboard controls.
4. Keep the deployment receipt and previous release for recovery.

Use `rollback.sh` with the recorded release revision if recovery is required.
Publication does not submit the app to the App Store.
