#!/bin/bash
set -e

CERTBOT_LOG=/run/certbot-logs/letsencrypt.log

# On any failure, dump the certbot log if it exists so the cause is visible
trap 'if [ -f "$CERTBOT_LOG" ]; then echo "--- certbot log ---"; cat "$CERTBOT_LOG"; fi' ERR

# 1. Update BunnyCDN A record with the current public IP.
if [ -n "$BUNNY_ZONEID" ] && [ -n "$BUNNY_RECORDID" ] && [ -n "$BUNNY_APIKEY" ] && [ -n "$DNS_SUBDOMAIN" ]; then
    CURRENT_IP=$(curl -4 icanhazip.com)
    echo "Updating DNS: ${DNS_SUBDOMAIN} -> ${CURRENT_IP}"
    curl -sf --request POST \
        --url "https://api.bunny.net/dnszone/${BUNNY_ZONEID}/records/${BUNNY_RECORDID}" \
        --header "AccessKey: ${BUNNY_APIKEY}" \
        --header 'Content-Type: application/json' \
        --data "{
            \"Type\": 0,
            \"Ttl\": 120,
            \"Value\": \"${CURRENT_IP}\",
            \"Name\": \"${DNS_SUBDOMAIN}\",
            \"Weight\": 100,
            \"Priority\": 0
        }"
    echo "DNS updated."
fi

# 2. Obtain/renew TLS certificate via certbot DNS challenge.
if [ -n "$CERTBOT_DOMAIN" ] && [ -n "$CERTBOT_EMAIL" ] && [ -n "$BUNNY_APIKEY" ]; then
    CERT_DIR="/run/letsencrypt"
    CREDS_FILE="/run/certbot-bunny.ini"

    printf 'dns_bunny_api_key = %s\n' "$BUNNY_APIKEY" > "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"

    certbot certonly \
        --authenticator dns-bunny \
        --dns-bunny-credentials "$CREDS_FILE" \
        --dns-bunny-propagation-seconds 60 \
        --config-dir "$CERT_DIR" \
        --work-dir /run/certbot-work \
        --logs-dir /run/certbot-logs \
        ${CERTBOT_STAGING:+--staging} \
        -d "$CERTBOT_DOMAIN" \
        --email "$CERTBOT_EMAIL" \
        --non-interactive --agree-tos \
        --keep-until-expiring

    CERT="${CERT_DIR}/live/${CERTBOT_DOMAIN}/fullchain.pem"
    KEY="${CERT_DIR}/live/${CERTBOT_DOMAIN}/privkey.pem"

    export MOQ_SERVER_TLS_CERT="$CERT"
    export MOQ_SERVER_TLS_KEY="$KEY"
    export MOQ_WEB_HTTPS_CERT="$CERT"
    export MOQ_WEB_HTTPS_KEY="$KEY"
fi

exec /usr/local/bin/moq-relay "$@"
