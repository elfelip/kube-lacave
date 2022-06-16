FROM registry.access.redhat.com/ubi8/ubi

#RUN dnf -y --setopt=tsflags=nodocs update
RUN dnf -y update
RUN dnf install -y wget hostname
# Install language pack
RUN export GLIBC_VERSION=$(curl https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/ | grep glibc-langpack-fr | awk -F'glibc-langpack-fr-' '{print $2}' | awk -F'.el8.x86_64.rpm' '{print $1}' | tail -1) && \
	dnf install -y \
	https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-${GLIBC_VERSION}.el8.x86_64.rpm \
	https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-common-${GLIBC_VERSION}.el8.x86_64.rpm \
	https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-all-langpacks-${GLIBC_VERSION}.el8.x86_64.rpm \
	https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-langpack-fr-${GLIBC_VERSION}.el8.x86_64.rpm \
	https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-minimal-langpack-${GLIBC_VERSION}.el8.x86_64.rpm 

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
