#FROM quay.io/gambol99/keycloak-proxy:v2.1.1
FROM keycloak/keycloak-gatekeeper:latest

ADD lacave-root-ca.crt /usr/local/share/ca-certificates/lacave-root-ca.crt
RUN apk add --no-cache curl
RUN update-ca-certificates