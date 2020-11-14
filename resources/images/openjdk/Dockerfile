FROM registry.access.redhat.com/ubi8/ubi

RUN dnf -y --setopt=tsflags=nodocs update
RUN dnf install -y wget hostname
RUN dnf install -y https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-2.28-129.el8.x86_64.rpm https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-common-2.28-129.el8.x86_64.rpm https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-all-langpacks-2.28-129.el8.x86_64.rpm https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-langpack-fr-2.28-129.el8.x86_64.rpm https://rpmfind.net/linux/centos/8-stream/BaseOS/x86_64/os/Packages/glibc-minimal-langpack-2.28-129.el8.x86_64.rpm

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
RUN /install-java.sh 11
RUN /install-ca.sh