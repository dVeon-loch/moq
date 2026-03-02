#!/bin/bash
set -e

CERTBOT_LOG=/var/log/letsencrypt/letsencrypt.log

# On any failure, dump the certbot log if it exists so the cause is visible
trap 'if [ -f "$CERTBOT_LOG" ]; then echo "--- certbot log ---"; cat "$CERTBOT_LOG"; fi' ERR

# Obtain/renew TLS certificate via certbot standalone HTTP challenge.
# Requires port 80 to be open and the domain's A record to already point at this host.
if [ -n "$CERTBOT_DOMAIN" ] && [ -n "$CERTBOT_EMAIL" ]; then
    CERT_DIR="/run/letsencrypt"

    certbot certonly \
        --standalone \
        --config-dir "$CERT_DIR" \
        ${CERTBOT_STAGING:+--staging -vvv} \
        -d "$CERTBOT_DOMAIN" \
        --email "$CERTBOT_EMAIL" \
        --non-interactive --agree-tos \
        --keep-until-expiring

    CERT="${CERT_DIR}/live/${CERTBOT_DOMAIN}/fullchain.pem"
    KEY="${CERT_DIR}/live/${CERTBOT_DOMAIN}/privkey.pem"

    if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
        echo "ERROR: cert files not found after certbot:"
        echo "  cert: $CERT"
        echo "  key:  $KEY"
        ls -la "${CERT_DIR}/live/" 2>/dev/null || echo "  (live/ dir does not exist)"
        exit 1
    fi

    echo "Cert: $CERT"
    echo "Key:  $KEY"

    export MOQ_SERVER_TLS_CERT="$CERT"
    export MOQ_SERVER_TLS_KEY="$KEY"
    export MOQ_WEB_HTTPS_CERT="$CERT"
    export MOQ_WEB_HTTPS_KEY="$KEY"
fi

echo "Starting moq-relay..."
exec /usr/local/bin/moq-relay "$@"
