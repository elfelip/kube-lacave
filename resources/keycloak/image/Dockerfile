ARG KEYCLOAK_IMAGE=jboss/keycloak
ARG KEYCLOAK_VERSION=10.0.2
FROM ${KEYCLOAK_IMAGE}:${KEYCLOAK_VERSION}

ENV KEYCLOAK_IMAGE=${KEYCLOAK_IMAGE}
ENV KEYCLOAK_VERSION=${KEYCLOAK_VERSION}

ADD cli/TCPPING.cli /opt/jboss/tools/cli/jgroups/discovery/
ADD cli/JDBC_PING.cli /opt/jboss/tools/cli/jgroups/discovery/