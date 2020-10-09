#!/bin/bash
EPEL_PACKAGE_URL=${EPEL_URL:-https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm}
case "$1" in
	8)
		yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
		;;
	9)
		yum -y install unzip
		PATCH=$(echo $JDK_VERSION| awk -F+ '{print $2}')
		curl -k ${NEXUS_URL}/jdk-${JDK_VERSION}_linux-x64_ri.zip -o /tmp/openjdk.zip
		unzip /tmp/openjdk.zip -d /opt
		rm /tmp/openjdk.zip
		;;
	10)
		curl -k ${NEXUS_URL}/jdk-10_linux-x64_bin_ri.tar.gz -o /tmp/openjdk.tar.gz
		tar -xzvf /tmp/openjdk.tar.gz -C /opt
		rm /tmp/openjdk.tar.gz
		;;
	11)
		yum install -y java-11-openjdk java-11-openjdk-devel
		;;
	12)
		curl -k ${NEXUS_URL}/openjdk-${JDK_VERSION}_linux-x64_bin.tar.gz -o /tmp/openjdk.tar.gz
		tar -xzvf /tmp/openjdk.tar.gz -C /opt 
		rm /tmp/openjdk.tar.gz
		;;
	latest)
		yum install -y ${EPEL_PACKAGE_URL}
		yum install -y java-latest-openjdk java-latest-openjdk-devel java-latest-openjdk-jmods
		;;
	*)
		echo Version $JDK_VERSION de OpenJDK non supportée
		exit 1
		;;
esac

java -version 2>&1 | grep 'OpenJDK Runtime Environment' | awk -F'(' '{print $2}'| awk -F')' '{print $1}' | awk '{print $2}' | sed 's/+/_/g' > /openjdk.version
