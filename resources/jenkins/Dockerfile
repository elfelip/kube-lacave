FROM jenkins/jenkins:lts-centos

# Update
USER root
RUN dnf update -y

# install Maven
RUN dnf install -y sudo 
RUN echo 'jenkins ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/jenkins

# install Maven
RUN dnf install -y maven 

# install Java 11
RUN dnf install -y java-11-openjdk java-11-openjdk-devel

# Python, Ansible
RUN dnf install -y python3 python3-pip
RUN dnf install -y epel-release
RUN dnf install -y ansible

# Install Docker
RUN dnf -y install dnf-plugins-core && \
    dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo && \
    dnf install -y docker-ce-cli --nobest
RUN usermod -a -G docker jenkins

ENV GIT_USER_NAME="Jenkins Lacave"
ENV GIT_USER_EMAIL="elfelip@yahoo.com"

ADD certificats /certificats
ADD install-ca.sh /install-ca.sh
RUN chmod a+x /install-ca.sh
RUN /install-ca.sh
ADD prepare.sh /prepare.sh
RUN chmod a+x /prepare.sh
USER jenkins
