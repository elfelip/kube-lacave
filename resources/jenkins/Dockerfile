FROM jenkins/jenkins:lts-centos

# Update
USER root
RUN yum update -y

# install Maven
RUN yum install -y sudo 
RUN echo 'jenkins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/jenkins

# install Maven
RUN yum install -y maven 

# install Java 11
RUN yum install -y java-11-openjdk java-11-openjdk-devel java-latest-openjdk java-latest-openjdk-devel

# Python, Ansible
RUN yum install -y ansible python3-pip

# Install Docker
RUN yum install -y yum-utils && yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && yum install -y docker-ce-cli --nobest
RUN usermod -a -G docker jenkins

USER jenkins

# Distributed Builds plugins
RUN /usr/local/bin/install-plugins.sh ssh-slaves

# install Notifications and Publishing plugins
RUN /usr/local/bin/install-plugins.sh email-ext
RUN /usr/local/bin/install-plugins.sh mailer
RUN /usr/local/bin/install-plugins.sh slack

# Artifacts
RUN /usr/local/bin/install-plugins.sh htmlpublisher
RUN /usr/local/bin/install-plugins.sh junit

# UI
RUN /usr/local/bin/install-plugins.sh greenballs
RUN /usr/local/bin/install-plugins.sh simple-theme-plugin

# Scaling
RUN /usr/local/bin/install-plugins.sh kubernetes

# Git
RUN /usr/local/bin/install-plugins.sh git
RUN /usr/local/bin/install-plugins.sh git-parameter

# Pipeline
RUN /usr/local/bin/install-plugins.sh workflow-job
RUN /usr/local/bin/install-plugins.sh workflow-aggregator
RUN /usr/local/bin/install-plugins.sh pipeline-build-step
RUN /usr/local/bin/install-plugins.sh pipeline-model-definition

# DSL
RUN /usr/local/bin/install-plugins.sh job-dsl

# Configuration du client GIT
#RUN git config --global user.name "Philippe Gauthier" && git config --global user.email "nobody@inspq.qc.ca" && git config --global credential.helper store

