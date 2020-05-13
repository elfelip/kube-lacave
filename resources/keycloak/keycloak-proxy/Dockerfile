FROM quay.io/gambol99/keycloak-proxy:v2.1.1

ADD lacave-root-ca.crt /usr/local/share/ca-certificates/lacave-root-ca.crt
RUN apk add --no-cache curl
RUN update-ca-certificates