FROM registry.access.redhat.com/ubi9/ubi

RUN dnf install -y wget hostname
# Install language pack
ENV LANGPACK_DOWNLOAD_URL=http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages
RUN export GLIBC_VERSION=$(curl ${LANGPACK_DOWNLOAD_URL}/ | grep glibc-langpack-fr | awk -F'glibc-langpack-fr-' '{print $2}' | awk -F'.el9.x86_64.rpm' '{print $1}' | tail -1) && \
	dnf install -y \
	${LANGPACK_DOWNLOAD_URL}/glibc-${GLIBC_VERSION}.el9.x86_64.rpm \
	${LANGPACK_DOWNLOAD_URL}/glibc-common-${GLIBC_VERSION}.el9.x86_64.rpm \
	${LANGPACK_DOWNLOAD_URL}/glibc-all-langpacks-${GLIBC_VERSION}.el9.x86_64.rpm \
	${LANGPACK_DOWNLOAD_URL}/glibc-langpack-fr-${GLIBC_VERSION}.el9.x86_64.rpm \
	${LANGPACK_DOWNLOAD_URL}/glibc-minimal-langpack-${GLIBC_VERSION}.el9.x86_64.rpm 
ENV TZ=America/Toronto

ARG JDK_VERSION=11
ENV CACERTS="-cacerts"

ARG NEXUS_URL=https://nexus3.inspq.qc.ca:8443/repository/utilitaires-infrastructure
ENV NEXUS_URL=${NEXUS_URL}

ENV EPEL_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
ADD certificats /tmp/certificats
ADD install-ca.sh /install-ca.sh
ADD install-java.sh /install-java.sh
RUN chmod a+x /install-ca.sh && chmod a+x /install-java.sh
RUN /install-java.sh ${JDK_VERSION}
RUN /install-ca.sh
RUN dnf -y update
