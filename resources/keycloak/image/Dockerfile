ARG KEYCLOAK_IMAGE=jboss/keycloak
ARG KEYCLOAK_VERSION=11.0.3
FROM ${KEYCLOAK_IMAGE}:${KEYCLOAK_VERSION}

USER root
ADD lacave-root-ca.crt /etc/pki/ca-trust/source/anchors/lacave-root-ca.crt
RUN keytool -noprompt -importcert -cacerts -storepass changeit -file /etc/pki/ca-trust/source/anchors/lacave-root-ca.crt -alias root_lacaveinfo
RUN update-ca-trust extract
USER jboss

ENV KEYCLOAK_IMAGE=${KEYCLOAK_IMAGE}
ENV KEYCLOAK_VERSION=${KEYCLOAK_VERSION}

ADD cli/TCPPING.cli /opt/jboss/tools/cli/jgroups/discovery/
ADD cli/JDBC_PING.cli /opt/jboss/tools/cli/jgroups/discovery/
