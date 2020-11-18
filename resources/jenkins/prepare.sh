#!/bin/bash

sudo chown -R 1000:1000 /var/jenkins_home

# Distributed Builds plugins
/usr/local/bin/install-plugins.sh ssh-slaves

# install Notifications and Publishing plugins
/usr/local/bin/install-plugins.sh email-ext
/usr/local/bin/install-plugins.sh mailer
/usr/local/bin/install-plugins.sh slack

# Artifacts
/usr/local/bin/install-plugins.sh htmlpublisher
/usr/local/bin/install-plugins.sh junit

# UI
/usr/local/bin/install-plugins.sh greenballs
/usr/local/bin/install-plugins.sh simple-theme-plugin

# Scaling
/usr/local/bin/install-plugins.sh kubernetes

# Git
/usr/local/bin/install-plugins.sh git
/usr/local/bin/install-plugins.sh git-parameter

# Pipeline
/usr/local/bin/install-plugins.sh workflow-job
/usr/local/bin/install-plugins.sh workflow-aggregator
/usr/local/bin/install-plugins.sh pipeline-build-step
/usr/local/bin/install-plugins.sh pipeline-model-definition

# DSL
/usr/local/bin/install-plugins.sh job-dsl

if [ ! -d /var/jenkins_home/.ssh ]; then
    echo "Configuer la cle SSH"
    ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa <<<y 2>&1 >/dev/null
fi

# Configuration du client GIT
if [ ! -f /var/jenkins_home/.gitconfig ]; then
    echo "Configuer le client git"
    git config --global user.name "${GIT_USER_NAME}" && git config --global user.email "${GIT_USER_EMAIL}" && git config --global credential.helper store
fi