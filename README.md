# Projet cluster Kubernetes
Ce projet permet de créer un cluster Kubernetes sur CoreOS/Flatcar

# Préparation du serveur de provisionning
On fait l'installation du cluster à partir d'un ordinateur externe. J'ai utilise une machine Ubuntu pour le faire.
On choisi un utilisateur de l'OS qui servira à faire les installation. Ca peut être un ustilisateur normal, l'utilisateur Jenkins si Jenkins est utilisé pour lancer les scripts de déploiement ou un utilisateur Ansible.

On dit premièrement générer les clés RSA avec ssh:

    ssh-keygen
    Ne pas entrer de passphrase

La deuxième étape est d'installer Ansible: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html

    sudo apt update
    sudo apt install software-properties-common
    sudo apt-add-repository --yes --update ppa:ansible/ansible
    sudo apt install ansible

Créer un fichier de mot de passe pour ansible vault

    sudo bash -c 'uuidgen > /etc/ansible/passfile'

Il sera alors possible d'utiliser ansible vault pour crypter des donnés dans l'inventaire.
On peut créer le script /usr/local/bin/encrypt-ansible suivant :

    #!/bin/bash
    ansible-vault encrypt_string $2 --vault-id lacave@/etc/ansible/passfile --name $1

Et le rendre exécutable:

    sudo chmod a+x /usr/local/bin/encrypt-ansible

Finalement on peut crypter des variables de l'inventaire. Ex.

    encrypt-ansible nexus_admin_password LeMotDePasse

## Installer le dépôt du projet

On doit ensuite faire un clone du projet avec la commande git:

    git clone --recurse-submodules https://github.com/elfelip/kube-lacave.git

Se déplacer ensuite dans le répertoire kube-lacave/kubespray
Obtenir toute les branches:

    git fetch --all

Faire une checkout de la branche qui contient le correctif pour Fedora CoreOS

    git checkout correctif_fedora
    git pull origin correctif_fedora

# Configuration DNS

Dans notre installation, Un serveur DNS bind est installé sur le serveur de povisionning.
Le fichier de zone pour lacave est /etc/bind/lacave.info.db

    On créé des entres DNS pour les 3 noeuds ainsi que l'entré kube.lacave pour les 3 adresses IP des noeuds du cluster.
    kube01.lacave.info. IN  A   192.168.1.21
    kube02.lacave.info. IN  A   192.168.1.22
    kube03.lacave.info. IN  A   192.168.1.23
    kube.lacave.info.   IN  A   192.168.1.21
                        IN  A   192.168.1.22
                        IN  A   192.168.1.23
    
    *.kube.lacave.info	IN  CNAME	kube.lacave.info.

Le CNAME *.kube permet de faire résoudre tous les services publiés dans le cluster tant qu'il sont dans la zone kube.lacave.info

# Création du PKI
Afin de faciliter le création de certificats self-signed, on se cré un petite infrastructure à clé publique sur le serveur de provisionning.
Référence: https://pki-tutorial.readthedocs.io/en/latest/simple/index.html
La chaine de confiance ainsi que les clés de ce PKI ne sont pas incluses dans le projet GIT.
On peut le référencer lorsqu'on utilise le playbook Ansible de configuration du cluster.

# Préparation des noeuds
La première étape est d'installer un système d'exploitation sur les noeuds physiques ou virtuel.
Pour ce projet on a choisi Fedora CoreOS avec l'engin de conteneur crio. On aurait aussi pu utiliser Flatcar Container Linux qui est un fork de CoreOS suite à son achat par RedHat.

## Fichier ignition
Pour la configurtation des serveurs, on créé un fichier Yaml.

Pour nos besoins, le fichier contient le user root avec la clé rsa à ajouter à sez authorozed_keys, une adresse IP fixe et un nom d'hôte.

La structure est la suivante pour nos 4 machines:

    kube01.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.21/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube01
    kube02.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.22/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube02
    kube03.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/eth0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=eth0

            [ipv4]
            method=manual
            addresses=192.168.1.23/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube03
    kube04.fcc
    -------------------
    variant: fcos
    version: 1.1.0
    passwd: 
    users:
    - name: root
        ssh_authorized_keys:
        - ssh-rsa 
        LACLERSAPUBLIQUE
    storage:
    files:
        - path: /etc/NetworkManager/system-connections/enp3s0.nmconnection
        mode: 0600
        overwrite: true
        contents:
            inline: |
            [connection]
            type=ethernet
            interface-name=enp3s0

            [ipv4]
            method=manual
            addresses=192.168.1.24/24
            gateway=192.168.1.1
            dns=192.168.1.10
            dns-search=lacave
        - path: /etc/hostname
        mode: 420
        contents:
            inline: kube01


Pour créer le fichier ignition en format JSON utilisable par le processus d'installation, lancer les commandes suivantes:

    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube01.fcc > kube01.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube02.fcc > kube02.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube03.fcc > kube03.ign
    docker run -i --rm quay.io/coreos/fcct:release --pretty --strict < kube04.fcc > kube04.ign

Pour l'installation, on doit mettre les fichiers *.ign sur un serveur Web. Dans mopn cas, je les ai mis sur mon serveur elrond qui est en Ubuntu et qui a Apache installé dessus, dans le répertoire /var/www/html/kubernetes

## Installation de Fedora CoreOS
J'ai utilisé un DVD fait à partir de l'ISO disponible sur le site de Fedora.

Pour que ca fonctionne avec Crio et Fedora CoreOS, on doit faire manuellement le correctif suivant à Kubespray.
https://github.com/kubernetes/kubeadm/issues/1495

La modification a été poussée dans mon repository de Kubespray: https://github.com/elfelip/kubespray.git

### kube01
Démarrer à partir du CD.

S'il y a un système d'exploitation sur le disque de destination, il peut être nécessaire de le remettre à 0 en utilisant les commandes suivantes:

    DISK="/dev/sda"
    # Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
    # You will have to run this step for all disks.
    sudo sgdisk --zap-all $DISK
    # Clean hdds with dd
    sudo dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync status=progress

Redémarrer ensuite le système

    sudo init 6
On peut ensuite installer l'OS avec la commande suivante:

    sudo coreos-installer install /dev/sda --ignition-url http://elrond.lacave/kubernetes/kube01.ign --insecure-ignition

L'option --insecure-ignition est nécessaire si le serveur Web n'est pas en https.

Répéter sur les autres noeuds en utilisant les fichier kube0X.ign respectifs:

### kube02

sur le host kube02:

    sudo coreos-installer install /dev/sda --ignition-url http://elrond.lacave/kubernetes/kube02.ign --insecure-ignition

### kube03

sur le host kube03:

    sudo coreos-installer install /dev/sda --ignition-url http://elrond.lacave/kubernetes/kube03.ign --insecure-ignition

### kube04

sur le host kube04:

    sudo coreos-installer install /dev/sda --ignition-url http://elrond.lacave/kubernetes/kube04.ign --insecure-ignition

## Ajout du certifact de du root CA dans les trust stores des noeuds
Pour que docker soit en mesure de se connecter en https sur les services qui ont des certificats émis par notre PKI interne, on doit faire exécuter le script suivant:

    ./copycert.sh

# Préparation de l'inventaire Ansible de Kubespray

La configuration du cluster est décrite dans l'inentaire Ansible de Kubespray qui est dans le répertoire inventory/lacave de ce projet.

## Configurations des noeuds
On spécifie à Kubespray les noeuds à déployer dans le fichier principal de l'inventaire inventory.ini

    # ## Configure 'ip' variable to bind kubernetes services on a
    # ## different ip than the default iface
    # ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
    [all]
    kube01
    kube02
    kube03
    kube04
    # ## configure a bastion host if your nodes are not directly reachable
    # bastion ansible_host=x.x.x.x ansible_user=some_user

    [kube-master]
    kube01
    kube03

    [etcd]
    kube01
    kube02
    kube03

    [kube-node]
    kube01
    kube02
    kube03
    kube04

    [calico-rr]

    [k8s-cluster:children]
    kube-master
    kube-node
    calico-rr

Les configurations spécifiques à chaque noeuds sont dans les fichiers ru répertoire inventory/hosts_vars

## Les variables globales du projet

Les variables communes sont mises dans le fichier group_vars/all/all.yml
On y met les configuration propores à l'installation Ansible du serveur de gestion. Ex.

    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3

Et on y met aussi les configurations spécifiques aux éléments qu'on veut déployer dans notre cluster. Ex.

    project_name: lacave
    global_domain_name: "{{ project_name }}.info"
    kube_domain_name: "kube.{{ global_domain_name }}"
    self_signed_pki_path: /home/felip/pki
    self_signed_pki_key_password: !vault |
            $ANSIBLE_VAULT;1.2;AES256;lacave
            34373939393864666661386531613631363632636235393838623061373164333836316262323830
            6663663164663137333332306433303833323562656565660a643533323062356536386463623138
            64376261343032366462623831396362303264643563616333663737353635646163643332363262
            6362313362333330310a333764383937343630353465306565326432303465626634666136616636
            6535
    nexus_admin_password: !vault |
            $ANSIBLE_VAULT;1.2;AES256;lacave
            39386135303762333863353231326461303831306237323235336666633538343539326230323538
            6530616138306634636265356134353563346234386264660a343238623430366635303033353831
            63356536333236386437623034353431613361613534666333323639616432613034613532396535
            3937313837643265650a396562616361323863663830373063646434316362613237626135356338
            6231

Les variables contenant des mot de passes sont cryptés avec le script encrypt-ansible.

## Choix de la version de Kubernetes

Pour spécifier la version de Kubernetes à déployer on modifi la variable suivante du fichier group_vars/k8s-cluster/k8s-cluster.yml

    kube_version: v1.19.3

## Options d'authentification OpenID Connect pour le serveur API

Pour configurer l'authentification OpenID Connect du cluster, on modifie les variables suivante du fichier group_vars/k8s-cluster/k8s-cluster.yml.

    kube_oidc_url: URL de base de votre serveur OpenID Connect
    kube_oidc_client_id: Client ID qui ser créé plus loin dans ce document
    ## Optional settings for OIDC
    kube_oidc_ca_file: Fichier de certificat de confiance
    kube_oidc_username_claim: preferred_username
    kube_oidc_username_prefix: 'oidc:'
    kube_oidc_groups_claim: groups
    kube_oidc_groups_prefix: 'oidc:'

Pour kube-lacave on a les paramètres suivants:

    kube_oidc_url: https://login.kube.lacave.info/auth/realms/kubernetes
    kube_oidc_client_id: kubelacave
    ## Optional settings for OIDC
    kube_oidc_ca_file: "{{ kube_cert_dir }}/lacave-root.pem"
    kube_oidc_username_claim: preferred_username
    kube_oidc_username_prefix: 'oidc:'
    kube_oidc_groups_claim: groups
    kube_oidc_groups_prefix: 'oidc:'

On peut appliquer cette configuration à un nouveau cluster même si le serveur Keycloak en question doit être hébergé dessus et n'existe nécessairement pas. L'authentification par certificat est activé par défaut pa Kubespray et c'est la méthode utilisé par l'outil kubectl.

## Composants supplémentaires

On peut activer le déploiement de certains composants optionnels par Kubespray en ajustant des variables dans le fichier k8s-cluster/addons.yml

Les sections suivantes décrivent les composants qu'on a utilisés dans ce projet mais il y a d'autres composants qui peuvent être déployés et pris en charge par Kubespray.

### Kubernetes dashboard
On peut activer le dashboard avec la variable suivante:

    dashboard_enabled: true

### Helm deployment
On peut déployer les composants nécessaires à l'utilisation de helm avec la variable suivante:

    helm_enabled: true

### Registry deployment
Kuberspary peut déployer une registre d'images de conteneurs. Les options pour le registre docker interne son les suivantes:

    registry_enabled: true
    registry_namespace: kube-system
    registry_storage_class: "local-path"
    registry_disk_size: "10Gi"

### Rancher Local Path Provisioner
Pour déployer Racher permettant de gérer l'allocation de volume locaux sur les noeuds du cluster, on utilise les variables suivantes:

    local_path_provisioner_enabled: true
    local_path_provisioner_namespace: "local-path-storage"
    local_path_provisioner_storage_class: "local-path"
    local_path_provisioner_reclaim_policy: Delete
    local_path_provisioner_claim_root: /opt/local-path-provisioner/
    local_path_provisioner_debug: false
    local_path_provisioner_image_repo: "rancher/local-path-provisioner"
    local_path_provisioner_image_tag: "v0.0.2"

### Nginx ingress controller deployment
Voici les options pour le déploiement du Ingress NGINX. C'est ce composant qu'on utilie principalelement dans ce projet pour exposer les applications qui sont déployés dans le cluster Kubernetes.

    ingress_nginx_enabled: true
    ingress_nginx_host_network: true
    ingress_publish_status_address: ""
    # ingress_nginx_nodeselector:
    #   beta.kubernetes.io/os: "linux"
    # ingress_nginx_tolerations:
    #   - key: "node-role.kubernetes.io/master"
    #     operator: "Equal"
    #     value: ""
    #     effect: "NoSchedule"
    ingress_nginx_namespace: "ingress-nginx"
    ingress_nginx_insecure_port: 80
    ingress_nginx_secure_port: 443
    # ingress_nginx_configmap:
    #   map-hash-bucket-size: "128"
    #   ssl-protocols: "SSLv2"
    # ingress_nginx_configmap_tcp_services:
    #   9000: "default/example-go:8080"
    # ingress_nginx_configmap_udp_services:
    #   53: "kube-system/coredns:53"
    # ingress_nginx_extra_args:
    #   - --default-ssl-certificate=default/foo-tls

### Cert manager deployment
On pourrait laisser Kubespray déployer le cert-manager mais avec les version expérimentés dans ce projet, il n'a pas été possible de déployer un cert-manager fonctionnels. Il est donc désactivé à ce niveau. Une section plus loin dans le document explique comment le déployer

    cert_manager_enabled: false
    #cert_manager_enabled: true
    #cert_manager_namespace: "cert-manager"

# Installation du Cluster

S'assurer d'être dans le répertoire kube-lacave et lancer le playbook de déploiement du cluster:

    ansible-playbook -i inventory/lacave/inventory.ini kubespray/cluster.yml

Sur Fedora Core OS, on recoit le message suivant:
TASK [bootstrap-os : Reboot immediately for updated ostree, please run playbook again if failed first time.] *****************
On doir donc attendre que les serveurs redémarrent et relancer le playbook

Assigner un rôle au noeud kube02:

    kubectl label node kube02 node-role.kubernetes.io/worker=worker

Les informations de connexion au cluster sont automatiquement ajouté dans le répertoire inventaire/lacave/

# Installation automatisée

Ce projet contient le playbook Ansible setup_cluster.yml qui permet d'installer les composants supplémentaires sur le cluster.
Il permet de faire automatiquement toutes les opérations manuelles décites en Annexe.

Installer les rôles et collections pré-requises a l'exécution du playbook.

    ansible-galaxy collection install -r requirements.yml

Pour exécuter le playbook, lancer la commande suivante:

    ansible-playbook --vault-id /etc/ansible/passfile -i inventory/lacave/inventory.ini setup_cluster.yml

# Configurer Ansible
Installer les pré-requis pour le module Ansible k8s. Ces instructions sont pour Ubuntu 18.04.

	sudo apt install python3-kubernetes
	pip3 install openshift --user

# Exécution du playbook de déploiement
A venir
On peut exécuter automatiquement les étapes décrite dans le document en exécutant la commande suivante:

    ansible-playbook -c local -i 'localhost,' deploy.yml
    

# Installer et configurer kubectl sur le serveur de provisionning ou de gestion
Pour faciliter les opérations, on installe et configure kubectl sur le serveur Jenkins/Ansible en effectuant les étapes suivantes:

Installer kubectl

L'outil kubectl a été installé et configuré par le playbook de déploiment du Cluster

Tester la connexion

    kubectl get pods -n kube-system
    NAME                                       READY     STATUS    RESTARTS   AGE
    calico-kube-controllers-7758fbf657-6gd9k   1/1       Running   0          13m
    ...

Si kubectl n'a pas été installé, on peut le faire sous Ubuntu avec la commande:

    sudo snap install kubectl

Pour le configurer, récupérer le fichier de configuration .kube/config de un des noeuds du cluster:

    scp -r root@kube01:.kube ~

# Déploiement du Dashboard

Kubespray déploie automatiquement le dashboard Kubernetes.

On doit toutefois créer l'utilisateur Admin en utilisant le manifeste du sous-répertoire resources du projet.

    kubectl apply -f resources/dashboard-adminuser.yml


# Utilisation

## Accéder à la console
Pour obtenir le jeton d'authentification, lancer les commandes suivantes à partir du premier noeud master du cluster en tant que root:

    kubectl get secret -n kube-system
    NAME                               TYPE                                  DATA   AGE
    admin-user-token-f85z5             kubernetes.io/service-account-token   3      63s
    default-token-ndnxp                kubernetes.io/service-account-token   3      74s
    kubernetes-dashboard-certs         Opaque                                0      74s
    kubernetes-dashboard-csrf          Opaque                                1      74s
    kubernetes-dashboard-key-holder    Opaque                                2      74s
    kubernetes-dashboard-token-mlpmn   kubernetes.io/service-account-token   3      74s

    TOKEN=$(kubectl get secret admin-user-token-ntxgf -n kube-system -o jsonpath='{.data.token}')
    echo $TOKEN
    ZXlKaGJHY2lPaUpTVXpJMU5pSXNJbXRwWkNJNklrUlhTREJqU....

On peut accéder à la console par l'adresse suivante:

    Par un port-forward:
    kubectl port-forward service/kubernetes-dashboard -n kube-system 8443:443
    URL: https://localhost:8443

## Kubectl
L'outil kubectl est installé et configuré automatiquement sur les deux noeuds maitres du cluster Kubernetes: kube01 et kube03 pour l'utilisateur root.

Il est possible de l'installer sur une autre machine. Pour configurer la connexion et l'authentification du client, on peut récupérer les informations qui sont dans le fichier config du répertoire /root/.kube des serveurs maitres. On doit modifier le paramètre server en fonction de l'emplacement réseau. On peut utiliser n'importe quel des noeuds maitre pour se connecter à l'API (kube01 ou kube03).

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1...
        server: https://kube01.lacave:6443
    name: labo.inspq
    contexts:
    - context:
        cluster: cluster.lacave
        user: kubernetes-admin
    name: kubernetes-admin@labo.inspq
    current-context: kubernetes-admin@labo.inspq
    kind: Config
    preferences: {}
    users:
    - name: kubernetes-admin
    user:
        client-certificate-data: LS0tLS1...
        client-key-data: LS0tLS1...

Le contexte par défaut est kubernetes-admin@labo.inspq. On peut spécifier le contexte à utiliser pour kubectl de la manière suivante:

    kubectl --context=kubernetes-admin@cluster.lacave

# Gestion des certificats

## Installation cert-manager
Cert Manager peut être installé par kubespray mais la version déployé semble limité.
On peut en installer un version plus récente avec la commande suivante:

    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml

## Création de l'émetteur de certificat SelfSigned pour lacave
Cert-manager peut créer des certificats en utilisant une autoirité de certification selfsigned. Pour créer cet émetteur au niveau du cluster, exécuter le manifest suivant:

    kubectl create -f resources/cert/root-ca-cert-manager.yml

# Stockage
Après l'installation de Kubespray avec l'inventaire actuel, seul le stockage local est disponible. Ce stockage n'est ni portable d'un noeud à l'autre ni redontant. 

## Stockage Ceph avec l'opérateur Rook
Pour ajouter la redondance au niveau du stockage on va installer l'opérateur CEPH rook: https://rook.io

Cet opérateur scrute continuellement les noeuds du cluster Kubernetes et détecte automatiquement les nouveau disques qui y sont attachés. Si les disques sont vides, il va automatiquement l'ajouter au cluster.

Les manifests utilisés proviennent du dépôt git https://github.com/rook/rook.git

On a suivi certaines étapes du LAB Rook-on-Bare-Metal-Workshop disponible sur github: https://github.com/packet-labs/Rook-on-Bare-Metal-Workshop 

La première étape est d'ajouter des disques sur les noeuds. On doit ajouter au moins 3 disques et les mettre sur des noeuds différents pour répondre aux exigeances de redondance de CEPH.

Le disques ne doivent pas avoir de partition existantes: J'ai du supprimer les données de mes disques en utilisant la commande suivante en tant que root sur les noeuds. ATTENTION, NE PAS EXECUTER CETTE COMMANDE SUR UN DISQUE UTILISÉ. CA VA TOUT SUPPRIMER SANS AVERTISSEMENT ET EN UN TEMPS RECORD...

    ls -l /dev/sd*
    brw-rw----. 1 root disk 8,  0 Jun 25 12:38 /dev/sda
    brw-rw----. 1 root disk 8,  1 Jun 25 12:38 /dev/sda1
    brw-rw----. 1 root disk 8,  2 Jun 25 12:38 /dev/sda2
    brw-rw----. 1 root disk 8,  3 Jun 25 12:38 /dev/sda3
    brw-rw----. 1 root disk 8,  4 Jun 25 12:38 /dev/sda4
    brw-rw----. 1 root disk 8,  6 Jun 25 12:38 /dev/sda6
    brw-rw----. 1 root disk 8,  7 Jun 25 12:38 /dev/sda7
    brw-rw----. 1 root disk 8,  9 Jun 25 12:38 /dev/sda9
    brw-rw----. 1 root disk 8, 16 Jun 25 12:38 /dev/sdb
    # On peut voir que /dev/sda est utilisé par le système d'exploitation et que /dev/sdb est libre.
    dd if=/dev/zero of=/dev/sdb bs=512 count=1

Les manifest pour créer l'opérateur sont dans le répertoire resources/rook.

    1) Le premier manifest crée les Custom Resource Definition et le namespace rook-ceph
        kubectl apply -f resources/rook/common.yaml
    2) Le deuxième manifest créé l'opérateur.
        kubectl apply -r resources/rook/operator.yaml
    3) On doit ensuite attendre que tous les pods soient créé avant de passer à l'étape suivante:
        watch kubectl get pods -n rook-ceph
        rook-ceph-operator-5b6674cb6-mrwb5                 1/1     Running     0          13h
        rook-discover-2b87n                                1/1     Running     1          17h
        rook-discover-bdq74                                1/1     Running     1          17h
        rook-discover-c4c9b                                1/1     Running     1          17h
        rook-discover-nvstr                                1/1     Running     1          17h
    4) On peut ensuite créer le cluster CEPH.
        kubectl apply -f resources/rook/cluster.yaml
    5) On peut suivre l'évolution de la création du cluster avec la commande suivante:
        watch kubectl get CephCluster -n rook-ceph
        NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH
        rook-ceph   /var/lib/rook     3          24h   Ready   Cluster created successfully   OK
    6) L'opérateur Rook a aussi déployé une console d'administation du cluster Ceph. Pour faciliter l'accessibilité à cette console on créé l'entré DNS suivant dans la zone lacave.info:
        cephdashboard.kube.lacave.info
        et un Ingress:
        kubectl apply -f resources/rook/dashboard-ingress-https.yaml
    7) Lancer la commande suivante pour obtenir le mot de passe de l'utilisateur admin de la console:
        kubectl get secret -n rook-ceph rook-ceph-dashboard-password -o jsonpath='{.data.password}' | base64 -d
    8) Créer le pool CEPH.
        kubectl apply -f resources/rook/pool.yaml
    8) Créer le storage class.
        kubectl apply -f resources/rook/storageclass.yaml

## Ajout d'un nouveau disque
En principe, si un nouveau disque vide est attaché à un noeud du cluster, un nouveau OSD devrait être créé automatiquement.
Dans le cas ou la détection ne fonctionnerait pas on peut redémarrer l'opérateur en supprimant le pod avec la commmande suivante:

    kubectl -n rook-ceph delete pod -l app=rook-ceph-operator

## Outils d'administration de CEPH
Rook inclu une image toolbox contenant les outils d'administration et de diagnostiques de CEPH. 
La documentation est disponible à l'adresse https://rook.io/docs/rook/v1.3/ceph-toolbox.html
Utiliser le manifest suivant pour l'installer:

    kubectl apply -f resources/rook/toolbox.yaml

Pour l'utiliser:

    kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
    ceph status 
    cluster:
        id:     3a286781-4924-4b95-806c-3113bd166395
        health: HEALTH_WARN
                1 daemons have recently crashed
    
    services:
        mon: 3 daemons, quorum d,f,g (age 38h)
        mgr: a(active, since 43m)
        osd: 3 osds: 3 up (since 23h), 3 in (since 23h)
    
    data:
        pools:   1 pools, 32 pgs
        objects: 2.88k objects, 11 GiB
        usage:   33 GiB used, 964 GiB / 997 GiB avail
        pgs:     32 active+clean
    
    io:
        client:   341 B/s wr, 0 op/s rd, 0 op/s wr

On peut créer l'alias suivant pour facluiliter l'utilisation du toolbox.

    alias ceph-toolbox='kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath="{.items[0].metadata.name}") bash'

Ajouter cette lign dans votre fichier ~/.bashrc pour que l'alias soit toujours disponible.

# Dépot Nexus
Pour entreposer des artefacts, dont les images de conteneurs, on utilise un serveur Nexus.
Pour le déployer, utiliser le manifest suivant:

    kubectl apply -f resources/nexus/nexus-deployment.yml

Le serveur nexus est accessible par l'URL https://nexus.lacave.info
Le dépôt d'images de conteneurs est docker.lacave.info

# Authentification au registre Docker du Nexus

Suivre les étapes suivantes pour créer un secret utilisable par Kubernetes pour s'authentifier auprès du registre Docker du serveur Nexus:
Référence: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

S'authentifier au registre Docker du Nexus si ce n'est pas déjà fait:

    docker login docker.lacave.info

Vérifier que le ficher de config Docker pour identifier les informations d'authentification:

    cat ~/.docker/config.json 
{
	"auths": {
		"docker.lacave.info": {
			"auth": "LeSecretEstDansLaSauce"
		},
		"https://index.docker.io/v1/": {
			"auth": "LeSecretEstDansLaSauce"
		}
	}
}

Créer le secret dans Kubernetes:

    kubectl create secret generic regcred --from-file=.dockerconfigjson=${HOME}/.docker/config.json --type=kubernetes.io/dockerconfigjson -n kube-system
    kubectl create secret generic regcred --from-file=.dockerconfigjson=${HOME}/.docker/config.json --type=kubernetes.io/dockerconfigjson -n default

Ce secret doit être créé dans chacun des Namespace qui utilise le registre privé.

# Operateur Postgresql
Crunchy Data font un opérateur permettant de créer de cluster Postegresql redondant. https://github.com/CrunchyData/postgres-operator

## Installer l'opérateur
Pour l'installer, exécuter les commandes suivantes:

    kubectl create namespace pgo
    kubectl apply -f https://raw.githubusercontent.com/CrunchyData/postgres-operator/v4.3.2/installers/kubectl/postgres-operator.yml

Une fois l'opérateur déployé, on doit avoir les pods suivants dans le namespace pgo:

    kubectl get pods  -n pgo                
    NAME                                 READY   STATUS      RESTARTS   AGE
    pgo-deploy-m6wx4                     0/1     Completed   0          24h
    postgres-operator-5d486cb469-9kkws   4/4     Running     1          24h

## Installer le client

Utiliser le script setup_client.sh pour installer l'outil pgo:

    resrouces/crunchy/

Configurer l'environnement. Exécuter les commandes suivantes et les ajouter au ~/.bashrc

export PATH=${HOME}/.pgo/pgo:$PATH
echo "export PATH=${HOME}/.pgo/pgo:$PATH" >> ~/.bashrc
export PGOUSER=${HOME}/.pgo/pgo/pgouser
echo "export PGOUSER=${HOME}/.pgo/pgo/pgouser" >> ~/.bashrc
export PGO_CA_CERT=${HOME}/.pgo/pgo/client.crt
echo "export PGO_CA_CERT=${HOME}/.pgo/pgo/client.crt" >> ~/.bashrc
export PGO_CLIENT_CERT=${HOME}/.pgo/pgo/client.crt
echo "export PGO_CLIENT_CERT=${HOME}/.pgo/pgo/client.crt" >> ~/.bashrc
export PGO_CLIENT_KEY=${HOME}/.pgo/pgo/client.key
echo "export PGO_CLIENT_KEY=${HOME}/.pgo/pgo/client.key" >> ~/.bashrc
export PGO_APISERVER_URL=https://localhost:8443
echo "export PGO_APISERVER_URL=https://localhost:8443" >> ~/.bashrc
export PGO_NAMESPACE=pgo
echo "export PGO_NAMESPACE=pgo" >> ~/.bashrc

Définir les infromation d'authentification:

    echo "$(kubectl get secret -n pgo pgouser-admin -o json | jq -r .data.username | base64 -d):$(kubectl get secret -n pgo pgouser-admin -o json | jq -r .data.password | base64 -d)" > ${HOME?}/.pgo/pgouser

Utiliser kubectl pour faire une redirection de port:

    kubectl port-forward -n pgo svc/postgres-operator 8443:8443 &

On peut tester le client en exécutant les commandes suivantes:

    pgo test --all
    Nothing found.
    
    pgo version
    pgo client version 4.3.2
    pgo-apiserver version 4.3.2

## Créer un cluster

Voici la commande pour tester le cluster testcluster utilisant rook comme stockage

    pgo create cluster testcluster --storage-config=rook --pgbackrest-storage-config=rook --metrics
    created cluster: testcluster
    workflow id: e0a1bb2b-8ff0-4a65-90a0-45f0d00477c7
    database name: testcluster
    users:
            username: testuser password: UnMotDePasseLongEtComplexeGenereAutomatiquementParLOperateur

# Utilisation d'un client de base de données

Pour se connecter sur la BD:

    # Lancer un port-forward
    kubectl -n pgo port-forward svc/testcluster 5432:5432 &
    # Se connecter sur la BD avec pgadmin à l'adresse localhost:5432
    # On peut obtenir le nom d'utilisateur avec la commande suivante:
    kubectl get secret -n pgo testcluster-testuser-secret -o json | jq -r .data.username | base64 -d
    # On peut obtenir le mot de passe avecla commande suivante:
    kubectl get secret -n pgo testcluster-testuser-secret -o json | jq -r .data.password | base64 -d

# Configuration OpenID Connect

Pour pouvoir utiliser l'authentification OpenID Connect avec le kubeAPI, on doit avoir confiuguré le cluster en lui fournissant les informations nécessaire: URL du serveur Keycloak, client ID etc.
On a décrit, au début de ce document, comment le faire avec Kubespray.

Pour minkube, utiliser les informations sur la page suivante:

    https://minikube.sigs.k8s.io/docs/tutorials/openid_connect_auth/

Pour microk8s: J'ai pas trouvé mais ca doit ressembler à minikube.

## Création de la base de données
Pour mettre les données de Keycloak, on utilise un cluster Postgres créé par l'opérateur Crunchy

    # Créer le namespace
    pgo create namespace kcdatabases
    # Créer le cluster de base de données et la base de données de Keycloak
    pgo create cluster loginlacavecluster -n kcdatabases --database=keycloak --username=keycloak --password=keycloak --storage-config=rook --pgbackrest-storage-config=rook --metrics

## Créer l'image Keycloak avec les scripts supportant le clustering.
Pour mettre Keycloak en cluster, on utilise le protocol JDBC_PING pour le Jgroups. Pour ce faire, des scripts doivent être ajouté à l'image de base de Keycloak. Ces scripts sont inclus dans le présent projet, pour créer l'image Keycloak, lancer les commmandes suivantes:

    docker build --tag docker.lacave.info/lacave/keycloak:11.0.3 resources/keycloak/image/
    docker push docker.lacave.info/lacave/keycloak:11.0.3

## Installation de Keycloak
Pour faire l'authentification des utilisateurs sur le cluster on install un serveur Keycloak.
Lancer le manifest suivant pour créer le serveur Keycloak.

    kubectl create -f resources/keycloak/loginlacave-keycloak-manifest.yaml

S'assurer que le DNS contient une entrée login.kube.lacave.info qui pointe vers les adresses IP des noeuds du cluster.

Accéder ensuite au serveur Keycloak: https://login.kube.lacave.info/auth/
S'authentifier en tant que l'utilisateur admin/admin

S.V.P. Changer le mot de passe

## Création du REALM
Pour la sécurité de Kubernetes on créé le REALM kubernetes.

Pour créer le realm kubernetes, on peut importer le fichier resources/keycloak/kubernetes-realm.json.
Pour se faire, se connecter à la console Keycloak en tant qu'admin: https://login.kube.lacave.info
Dans le menu REALM en haut a grauche, cliquer sur le bouton add realm.
Cliquer sur le bouton Select file de l'item Import
Sélectionner le fichier resources/keycloak/kubernetes-realm.json
Ne pas modifier le nom et cliquer import.

Sinon, on peut créer les configurations manuellements en suivant les étapes Keycloak décrites dans le reste de ce document.

Si vous n'avez pas importé le realm, aller dans le menu REALM en haut a grauche, cliquer sur le bouton add realm.

    Name: kubernetes

Sélectionner ce realm pour les autres étapes.

## Création du client
Dans le realm master créer le client suivant:

    Client ID: kubelacave
    Root URL: http://localhost:8000
    Client Protocol: openid connect
    Access type: Confidential
    Ajouter le redirect uri: https://dashboard.kube.lacave.info
    Ajouter l'origin: https://dashboard.kube.lacave.info
    Prendre en note de Client Secret de l'oinglet Credentials.

Ajouter dans l'onglet mappers, cliquer Add builtin, sélectionner groups et cliquer Add selected
Dans l'onglet Roles, Ajouter le rôle kubernetes-user

## Création du scope de client
Pour que Keycloak configure l'audience dans le jeton d'authentification, on doit créer le client scope suivant:

    Dans le menu Client Scope cliquer sur le bouton Create.
    Entrer les informations suivantes et cliquer Save:
        Name: kube-lacave-audience
        Description: Scope pour Kubernetes
        Protocol: openid-connect
        Display On Consent Screen: On
        Include in Token Scope: On
    Aller ensuite dans l'onglet Mappers:
    Cliquer sur Create
    Entrer les informations suivantes et cliquer Save:
        Name: kube-lacave-audience
        Mapper Type: Audience
        Included Client Audience: kubelacave
        Add to ID token: On
        Add to access token: On

    Dans le menu Client
    Sélectionner le client kubelacave
    Dans l'onglet Client Scope
    Ajouter le scope kube-lacave-audience dans Assigned Default Client Scopes
    Dans l'onglet mappers
    Ajouter un mapper en cliquant sur le bouton Add Builtin.
    Cocher groups et cliquer Save


## Création du rôle de REALM pour les administrateurs du cluster

Dans le menu Roles: Créer le rôle cluster-admin et cliquer Save

Dans le menu Users: 

Créer l'utilisateur admin, lui définir un mot de passe complex.
Dans l'onglet Role Mappings, lui assigner le rôle cluster-admin.

## Créer l'association du rôle OIDC de cluster admin dans Kubernetes
Créer le cluster role binding pour OIDC

    kubectl apply -f resources/keycloak/oidc-cluster-admin-role-binding.yaml


## Configuration du client Kubectl pour OpenID Connect
Installer Kubelogin (dans ~/bin pour un utilisateur norma, dans /usr/local/bin pour une installation globale)

    cd ~/bin # ou cd /usr/local/bin
    curl -LO https://github.com/int128/kubelogin/releases/download/v1.19.0/kubelogin_linux_amd64.zip
    unzip kubelogin_linux_amd64.zip
    chmod a+x kubelogin
    ln -s kubelogin kubectl-oidc_login

Sur MacOS

    brew install int128/kubelogin/kubelogin
    sudo ln -s /usr/local/bin/kubelogin /usr/local/bin/oidc-login

    Pour ajouter l'autorité de certification: https://www.eduhk.hk/ocio/content/faq-how-add-root-certificate-mac-os-x
    
Ajouter ensuite la section suivante dans votre ficher .kube/config:

    apiVersion: v1
    - context:
        cluster: kube.lacave
        user: oidc
      name: oidc@kube.lacave
    users
    - name: oidc
        user:
            exec:
            apiVersion: client.authentication.k8s.io/v1beta1
            command: kubectl
            args:
            - oidc-login
            - get-token
            - --oidc-issuer-url=https://login.kube.lacave.info/auth/realms/kubernetes
            - --oidc-client-id=kubelacave
            - --oidc-client-secret=client-secret-de-kube-api

Pour utililiser ce profil:

    kubectl --context oidc@kube.lacave get nodes

S'authentifier en tant qu'admin dans Keycloak si vous ne l'êtes pas déjà.

## Proxy Open ID Connect pour la Dashboard

On créé un proxy Keycloak qui permet d'accéder au tableau de bord Kubernetes avec une Authentificaiton OpenID Connect.

On peut ensuite déployer le manifest qui crée le proxy:

    kubectl apply -f resources/keycloak/oidc-dashboard-proxy.yaml

S'assurer que l'entré DNS dashboard.kube.lacave existe dans le DNS et pointe vers les adresses des noeuds du Cluster.
On peut accéder au Dashboard par l'adresse https://dashboard.kube.lacave.info
S'authentifier en tant qu'admin dans Keycloak.

## Configuration des rôles pour une architecture mutualisée
Un cluster mutualisé (multi-tenant) permet le partage des ressources entre plusieurs équipes.
Le principes est que chaque équipe a un namespace. Il y a 3 types d'utilisateur pour un namespace:

    Administrateur du namespace (admin): Cet utilisateur peut effectuer toute les opérations tant qu'elle sont à l'intérieur de son namespace.
    Accès en modification (edit): Cet utilisateur peut créer, modifier et supprimer certains type d'objet dans un namespace comme des pods, des déploiement, des stateful set, des certificats etc. C'est habituellement le rôle qu'on donne au développeur.
    Accès en lecture (view): Ce rôle permet de voir les objets du namespace. Ca peut être utile pour du monitoring au donner des accès a un personne externe à l'équipe.

Dans notre exemple, on configure les rôles pour le namespace default.
La première étape est de se connecter au serveur Keycloak et de créer les rôles de realm suivants:

    default-namespace-admin: Administrateurs du namespace default
    default-namespace-edit: Développeur du namespace default
    default-namespace-view: Consulter les objets du namespace default

On créé ensuite les appartenances de rôles (RoleBindings) dans le namespace default en exécutant le manifest suivant:

    kubectl apply -f resources/multitenants-default-role-bindings.yaml



# Ajouter un noeud au cluster

Voici les étapes pour ajouter le noeud kube04 au cluster. Ce neoud servira a l'exécution de tâches applicatives (worker node).

La première étape est d'ajouter le nouveau noeud dans le DNS.

    Ajouter la lignbe suivante dans le fichier de zone:
        kube04.lacave   IN  A   192.168.1.24
    Incrémenter le nbuméro de série dans l'entête du ficher de zone.
    Rafraichir le DNS:
        sudo systemctl reload bind9

Installer Flatcar Container Linux tel que décrit dans la section de préparation des noeuds. Utiliser le fichier kube04-ignition.json

Copier le certificat sur le nouveau noeud.

    scp resources/cert/lacave-root.pem root@kube04:/etc/ssl/certs
    ssh root@kube04 update-ca-certificates
    ssh root@kube04 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube04:/etc/kubernetes/ssl

Ajouter le noeud dans l'inventaire Ansible. Modifier les sections suivantes du fichier inventory/lacave/inventory.ini

    [all]
    kube01
    kube02
    kube03
    kube04
    [kube-node]
    kube01
    kube02
    kube03
    kube04

Vérifier l'état des noeuds déjà en place:

    kubectl get nodes
    NAME     STATUS   ROLES    AGE   VERSION
    kube01   Ready    master   20d   v1.18.2
    kube02   Ready    worker   20d   v1.18.2
    kube03   Ready    master   20d   v1.18.2

S'assurer d'être dans le répertoire kube-lacave et lancer le playbook de déploiement du cluster:

    ansible-playbook -i inventory/lacave/inventory.ini kubespray/cluster.yml

Vérifier l'état des noeuds:

    kubectl get nodes
    NAME     STATUS   ROLES    AGE     VERSION
    kube01   Ready    master   20d     v1.18.2
    kube02   Ready    worker   20d     v1.18.2
    kube03   Ready    master   20d     v1.18.2
    kube04   Ready    <none>   2m17s   v1.18.2

Assigner un rôle au nouveau noeud:

    kubectl label node kube04 node-role.kubernetes.io/worker=worker

Vérifier l'état des noeuds:

    kubectl get nodes
    NAME     STATUS   ROLES    AGE     VERSION
    kube01   Ready    master   20d     v1.18.2
    kube02   Ready    worker   20d     v1.18.2
    kube03   Ready    master   20d     v1.18.2
    kube04   Ready    worker   3m59s   v1.18.2

Dans le cas actuel, le nouveau noeud est équipé d'un disque ssd. On peut donc lui ajouter cet étiquette de manière à pouvoir le sélectionner pour les tâches intensives en io.

    kubectl label nodes kube04 disktype=ssd

On devrait avoir l'état final suivant:

    kubectl get nodes --show-labels
    NAME     STATUS   ROLES    AGE     VERSION   LABELS
    kube01   Ready    master   20d     v1.18.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=kube01,kubernetes.io/os=linux,node-role.kubernetes.io/master=
    kube02   Ready    worker   20d     v1.18.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=kube02,kubernetes.io/os=linux,kubernetes.io/role=worker
    kube03   Ready    master   20d     v1.18.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=kube03,kubernetes.io/os=linux,node-role.kubernetes.io/master=
    kube04   Ready    worker   7m28s   v1.18.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,disktype=ssd,kubernetes.io/arch=amd64,kubernetes.io/hostname=kube04,kubernetes.io/os=linux,node-role.kubernetes.io/worker=worker

# Mettre à jour le cluster
La méthode décrite dans ce guide est la mise à jour gracieuse (Graceful). Elle permet de mettre à jour le cluster tout en gardant les applications disponibles.
Dans ce document, je présente un mise à jour minueure qui fait passer le cluster de la version 1.18.2 à 1.18.5.

    Se connecter sur le serveur de gestion Ansible.
    Se déplacer dans le projet kube-lacave et mettre à jour le projet
        git pull
    Se déplacer dans le sous-projet kubespray et faire un chackout de la branche master
        git checkout master
    S'assurer d'avoir le remote upstream de configuré sur le dépôt git officiel de kubespray
        git remote -v
    Sinon, l'ajouter
        git remote add upstream https://github.com/kubernetes-sigs/kubespray.git
    Mettre à jour la branche master à partir du upstream
        git pull upstream master
    Pousser les mises à jour dans la branche master de votre fork
        git push origin master
    Retourner dans le répertoire du proket kube-lacave et lancer le playbook upgrade-cluster.yml
        ansible-playbook -i inventory/lacave/inventory.ini kubespray/upgrade-cluster.yml -e kube_version=v1.18.5
    On peut suivre l'évolution de la mise à jour avec la commande suivante:
        kubectl get nodes
        NAME     STATUS                     ROLES    AGE   VERSION
        kube01   Ready                      master   27d   v1.18.5
        kube02   Ready,SchedulingDisabled   worker   27d   v1.18.2
        kube03   Ready                      master   27d   v1.18.5
        kube04   Ready                      worker   27d   v1.18.2        
    une fois la mise à jour terminée, on devrait avoir le résultat suivant:
    kubectl get nodes
    NAME     STATUS   ROLES    AGE   VERSION
    kube01   Ready    master   28d   v1.18.5
    kube02   Ready    worker   28d   v1.18.5
    kube03   Ready    master   28d   v1.18.5
    kube04   Ready    worker   27d   v1.18.5
    Mettre à jour l'inventaire pour partir avec cette version la prochaine fois qu'on utilise le playbook cluster.yml
    Ficher inventory/lacave/group_vars/k8s-cluster/k8s-cluster.yml:
        kube_version: v1.18.5

En cas de problème lors de la mise a jour d'un noeud, on peut corriger le situation et lancer de nouveau la mise à jour.
Il faut remettre en marche les noeud qui étati en cours de mise à jour avec les commandes suivantes:

    kubectl get nodes
    NAME     STATUS                     ROLES    AGE   VERSION
    kube01   Ready                      master   27d   v1.18.5
    kube02   Ready,SchedulingDisabled   worker   27d   v1.18.2
    kube03   Ready                      master   27d   v1.18.5
    kube04   Ready                      worker   27d   v1.18.2
    kubectl uncordon kube02
    kubectl get nodes
    NAME     STATUS   ROLES    AGE   VERSION
    kube01   Ready    master   27d   v1.18.5
    kube02   Ready    worker   27d   v1.18.2
    kube03   Ready    master   27d   v1.18.5
    kube04   Ready    worker   27d   v1.18.2

Quand j'ai fait le test, istio était déployé et la mise à jour n'a pas pu se faire sur tous les noeuds. J'ai supprimé istio et la mise à jour a bien fonctionné.
Ce sera à creuser dans la section service mesh.

## Mise à jour majeure
Voici les étapes prises pour mettre à jour le cluster de 1.18.5 vers 1.19.1

Utiliser les mêmes étapes que pour la mise à jour majeure pour mettre à jour Kubespray
S'assurer que tous les noeuds du cluster sont Ready:

    kubectl get nodes
    NAME     STATUS   ROLES    AGE   VERSION
    kube01   Ready    master   99d   v1.18.5
    kube02   Ready    worker   99d   v1.18.5
    kube03   Ready    master   99d   v1.18.5
    kube04   Ready    worker   99d   v1.18.5

Pour mettre à jour le cluster, lancer la commande suivante à partir du serveur de gestion Ansible.

    ansible-playbook -i inventory/lacave/inventory.ini kubespray/upgrade-cluster.yml -e kube_version=v1.19.1

## Supprimer un noeud
Voici les étapes pour supprimer un noeud du cluster Kubernetes.
Sur le serveur de gestion, se déplacer dans le projet kube-lacave.
S'assurer que le clone/checkout/pull du sous projet kubespray a été fait.
Supprimer le noeud avec la commande suivante:

    ansible-playbook -i inventory/lacave/inventory.ini -e node=kube04 -e reset_nodes=false kubespray/remove-node.yml

Il est possible que lq dernière étape ne se fasse pas automatiquement. On peut alors finaliser la suppression du noeud avec la commande suivante:

    kubectl delete node kube04

Enlever le noeud de l'inventaire: inventory/lacave/inventory.ini

    # ## Configure 'ip' variable to bind kubernetes services on a
    # ## different ip than the default iface
    # ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
    [all]
    kube01
    kube02
    kube03
    #kube04
    # ## configure a bastion host if your nodes are not directly reachable
    # bastion ansible_host=x.x.x.x ansible_user=some_user

    [kube-master]
    kube01
    kube03

    [etcd]
    kube01
    kube02
    kube03

    [kube-node]
    kube01
    kube02
    kube03
    #kube04

    [calico-rr]

    [k8s-cluster:children]
    kube-master
    kube-node
    calico-rr    

Ajouter, committer et pousser la modificiation dans le dépôt git:

    git add -- inventory/lacave/inventory.ini
    git commit -m "Enlever le noeud kube04"
    git push

# Monitoring
La solution la plus populaire pour la surveillance d'un cluster Kubernetes est la combinaison Prometheus et Grafana.

## Installation de Prometheus, Grafana et Node Exporter avec une charte helm
On utilise la charte helm kube-prometheus pour déployer l'opérateur Prometheus.

Ajouter le repository à votre installation de Helm

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add stable https://charts.helm.sh/stable
    helm repo update

Créer le namespace monitoring

    kubectl create namespace monitoring

Installer la charte en utilisant les personnalisation de ce projet:

    helm install -f resources/monitoring/kube-prometheus-helm-values.yaml lacave-prom prometheus-community/kube-prometheus-stack

Grafana est accessible à l'adresse http://grafana.kube.lacave.info
L'utilisateur est admin et le mot de passe se retrouve dans le fichier kube-prometheus-helm-values.yaml
On ajoute les dashboard suivants en allant dans le menu Dashboard -> Manage -> Import

    Ceph: ID: 7056


### Service monitor
Pour monitorer un composants, on doit crée une ressource ServiceMonitor qui décrit quel est le service de notre composant quyi expose les métriques pour Prometheus.

Voir la page suivante pour une bonne explication de comment ca marche et comment on peut diagnostiquer les problèmes de récupération des métriques: https://github.com/prometheus-operator/prometheus-operator/blob/master/Documentation/troubleshooting.md

### Surveillance du cluster ceph
Lors de l'installation du cluster ceph, le monitoring a été configuré par l'opérateur rook. Pour que Prometheus puisse les importer, on doit créer un service monitor:
Lancer la commande suivante pour le créer:

    kubectl apply -f resources/rook/mgr-service-monitor.yaml

On peut ensuite importer un tableau de bord pour ceph dans Grafana. L'identifiant de celui que j'ai utilisé est le 7056:

    https://grafana.com/grafana/dashboards/7056


# Journalisation
Cette section décrit les étapes pour déployer les services de journalisation

## ECK

Elastic Cloud on Kubernetes. https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-quickstart.html

Installer les CRD et l'opérateur ainsi que ses règles d'accès.

    kubectl apply -f https://download.elastic.co/downloads/eck/1.2.1/all-in-one.yaml
On peut alors surveiller son déploiment

    kubectl -n elastic-system logs -f statefulset.apps/elastic-operator

On peut alors créer des cluster Elasticsearch. Dans notre cas, on va en créer un pour recueillir les logs des pods.

    kubectl apply -f resources/journalisation/elasticsearch/kube-lacave-elasticsearch-manifest.yaml

Attendre que le serveur Elastic soit fonctionnel:

    watch ubectl get elastic -n elastic-system
    NAME                                                                   HEALTH   NODES   VERSION   PHASE   AGE
    elasticsearch.elasticsearch.k8s.elastic.co/kube-lacave-elasticsearch   green    1       7.9.3     Ready   4m39s

Installer Kibana

    kubectl apply -f resources/journalisation/kibana/kube-lacave-kibana-manifest.yaml

Attendre que le serveur Kibana soit disponible:

    watch kubectl get elastic -n elastic-system
    NAME                                                                   HEALTH   NODES   VERSION   PHASE   AGE
    elasticsearch.elasticsearch.k8s.elastic.co/kube-lacave-elasticsearch   green    1       7.9.3     Ready   40m

    NAME                                              HEALTH   NODES   VERSION   AGE
    kibana.kibana.k8s.elastic.co/kube-lacave-kibana   green    1       7.9.3     34m

Installer les beats pour recueillir les journaux des conteneurs.

    kubectl apply -f resources/journalisation/beats/kube-lacave-beats-manifest.yaml

Attendre que le beat soit disponbile:

    watch kubectl get elastic -n elastic-system
    NAME                                                                   HEALTH   NODES   VERSION   PHASE   AGE
    elasticsearch.elasticsearch.k8s.elastic.co/kube-lacave-elasticsearch   green    1       7.9.3     Ready   44m

    NAME                                              HEALTH   NODES   VERSION   AGE
    kibana.kibana.k8s.elastic.co/kube-lacave-kibana   green    1       7.9.3     38m

    NAME                                         HEALTH   AVAILABLE   EXPECTED   TYPE       VERSION   AGE
    beat.beat.k8s.elastic.co/kube-lacave-beats   green    4           4          filebeat   7.9.3     116s

Pour obtenir le mot de passe de l'utilisateur elastic:

    kubectl get secret kube-lacave-elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' -n elastic-system | base64 -d; echo

L'URL de kibana est https://kibana.kube.lacave.info

    S'authentifier en tant que elsastic avec le mot de passe trouvé à l'étape précédente.
    Naviguer dans le menu dans le haut à gauche de l'écran: menu Observability -> Logs. Cette étape permet de voir si les journaux des beats sont envoyés sur Elasticsearch et visibles par Kibana.
    Naviguer dans le menu Kibana -> Discover. On peut explorer les journaux et faire des requêtes pour les filtrer.


Installer APM Server. Cette partie n'est pas fonctionnelle encore...

    kubectl apply -f resources/journalisation/apm/kube-lacave-apm-manifest.yaml

### Ajout de la source de données dans Grafana
On peut utiliser grafana pour faire des tableaux de bords pour exploiter les données recueillis par Elasticsearch.

    Se connecter à Grafana
    Dans le menu de Configuration -> Datasource.
    Cliquer Add Datasource
    Choisir Elasticsearch
    Entrer les informations suivantes:
        Name: Elasticsearch
        HTTP:
            URL: https://kube-lacave-elasticsearch-es-http.elastic-system.svc:9200
            Access: Server
        Auth: Cocher Basic auth et With CA Cert
        Basic auth details:
            User: elastic
            Password: Lancer la commande suivante pour l'obtenir
            kubectl get secret kube-lacave-elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' -n elastic-system | base64 -d; echo
        TLS Auth Details:
            CA-cert: Lancer la commande suivante pour l'obtenir
            kubectl get secret kube-lacave-elasticsearch-es-http-certs-public -o "jsonpath={.data['ca\.crt']}" -n elastic-system | base64 -d; echo
        Elasticsearch details:
            Version: 7.0+
    Cliquer Save and Test

On ajoute les dashboard suivant en allant dans le menu Dashboard -> Manage -> Import

    Elasticsearch: ID: 8715

## Graylog
Graylog est aussi utilisé pour recueillir les journaux. On l'utilise pour les journaus applicatifs avec le module GELF.
Le déploiement de Graylog se fait en 3 étapes.

    Déployer un MongoDB
    Déployer Elasticsearch avec ECK
    Déployer Graylog

On doit premièrement créer le Namespace pour Graylog

    kubectl apply -f resources/journalisation/graylog/graylog-namespace.yaml

On créé ensuite le certificat SSL

    kubectl apply -f resources/journalisation/graylog/graylog-cert-manifest.yaml

### MongoDB
On utilise Helm pour déployer MongoDB. Les paramètres à utiliser pour la charte sont dans le fichier resources/journalisation/mongodb/kube-mongodb-helm-values.yaml
Pour le déployer

    Installer le repository Helm:
    helm repo add bitnami https://charts.bitnami.com/bitnami
    Déployer la charte avec les paramètres de notre cluster:
    helm install -f resources/journalisation/graylog/graylog-mongodb-helm-values.yaml lacave-graylog-mongodb bitnami/mongodb --namespace graylog-system
        NAME: lacave-graylog-mongodb
        LAST DEPLOYED: Thu Oct 22 08:52:10 2020
        NAMESPACE: graylog-system
        STATUS: deployed
        REVISION: 1
        TEST SUITE: None
        NOTES:
        ** Please be patient while the chart is being deployed **

        MongoDB can be accessed via port 27017 on the following DNS name(s) from within your cluster:

            lacave-graylog-mongodb.graylog-system.svc.cluster.lacave

        To get the root password run:

            export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace graylog-system lacave-graylog-mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)

        To get the password for "graylog" run:

            export MONGODB_PASSWORD=$(kubectl get secret --namespace graylog-system lacave-graylog-mongodb -o jsonpath="{.data.mongodb-password}" | base64 --decode)

        To connect to your database, create a MongoDB client container:

            kubectl run --namespace graylog-system lacave-graylog-mongodb-client --rm --tty -i --restart='Never' --image docker.io/bitnami/mongodb:4.4.1-debian-10-r39 --command -- bash

        Then, run the following command:
            mongo admin --host "lacave-graylog-mongodb" --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD

        To connect to your database from outside the cluster execute the following commands:

            kubectl port-forward --namespace graylog-system svc/lacave-graylog-mongodb 27017:27017 &
            mongo --host 127.0.0.1 --authenticationDatabase admin -p $MONGODB_ROOT_PASSWORD

### Elasticsearch avec Helm
Lancer la commande suivante pour installer Elasticsearch 6.7.2 avec la charte HELM stable.
Cette charte est dépréciée. Elle sera remplacé par l'opérateur lorsque Graylog pourra supporter la version 6.8 d'Elasticsearch.
    
    helm install --namespace graylog-system -f resources/journalisation/graylog/graylog-elasticsearch-helm-values.yaml lacave-graylog-elasticsearch stable/elasticsearch
    This Helm chart is deprecated. Please use https://github.com/elastic/helm-charts/tree/master/elasticsearch instead.

    ---

    The elasticsearch cluster has been installed.

    Elasticsearch can be accessed:

    * Within your cluster, at the following DNS name at port 9200:

        lacave-graylog-elasticsearch-client.graylog-system.svc

    * From outside the cluster, run these commands in the same shell:

        export POD_NAME=$(kubectl get pods --namespace graylog-system -l "app=elasticsearch,component=client,release=lacave-graylog-elasticsearch" -o jsonpath="{.items[0].metadata.name}")
        echo "Visit http://127.0.0.1:9200 to use Elasticsearch"
        kubectl port-forward --namespace graylog-system $POD_NAME 9200:9200    

### Elasticsearch avec l'opérateur
Ne pas utiliser l'opérateur pour le moment car il ne peut pas installer un version supportés par Graylog pour le moment
On utilise l'opérateur Elasticsearch déployé dans la section précédente pour le déployer pour Graylog.

    kubectl apply -f resources/journalisation/graylog/graylog-elasticsearch-manifest.yaml

Pour obtenir le mot de passe de l'utilisateur elastic:

    kubectl get secret graylog-elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' -n graylog-system | base64 -d; echo

On doit ajouter ce mot de passe dans la section elasticsearch du fichier resources/journalisation/graylog/graylog-helm-values.yaml
elasticsearch:

    hosts: http://elastic:LeMotDePasse@graylog-elasticsearch-es-http:9200

### Graylog
On utilise une charte helms avec u fichier de valeur pour créer le serveur Graylog:
Déployer le serveur Graylog avec la charte:

    helm install --namespace graylog-system -f resources/journalisation/graylog/graylog-helm-values.yaml lacave-graylog stable/graylog
        NAME: lacave-graylog
        LAST DEPLOYED: Wed Oct 21 22:34:55 2020
        NAMESPACE: graylog-system
        STATUS: deployed
        REVISION: 1
        TEST SUITE: None
        NOTES:
        To connect to your Graylog server:

        1. Get the application URL by running these commands:

        Graylog Web Interface uses JavaScript to get detail of each node. The client JavaScript cannot communicate to node when service type is `ClusterIP`. 
        If you want to access Graylog Web Interface, you need to enable Ingress.
            NOTE: Port Forward does not work with web interface.

        2. The Graylog root users

        echo "User: admin"
        echo "Password: $(kubectl get secret --namespace graylog-system lacave-graylog -o "jsonpath={.data['graylog-password-secret']}" | base64 --decode)"

        To send logs to graylog:

        NOTE: If `graylog.input` is empty, you cannot send logs from other services. Please make sure the value is not empty.
                See https://github.com/helm/charts/tree/master/stable/graylog#input for detail
        1. TCP
        export POD_NAME=$(kubectl get pods --namespace graylog-system -l "app.kubernetes.io/name=graylog,app.kubernetes.io/instance=lacave-graylog" -o jsonpath="{.items[0].metadata.name}")
        Run the command
        kubectl port-forward $POD_NAME 12222:12222
        Then send logs to 127.0.0.1:12222
        Run the command
        kubectl port-forward $POD_NAME 5061:5061
        Then send logs to 127.0.0.1:5061
        2. UDP
        export POD_NAME=$(kubectl get pods --namespace graylog-system -l "app.kubernetes.io/name=graylog,app.kubernetes.io/instance=lacave-graylog" -o jsonpath="{.items[0].metadata.name}")
        Run the command
        kubectl port-forward $POD_NAME 12231:12231
        Then send logs to 127.0.0.1:12231

Une fois graylog en route, pour pouvoir accéder à l'interface web en https, on doit modifier le configmap et redémarrer les pods.
Lancer la commande suivante pour modifier le configmap:

    kubectl edit configmap lacave-graylog -n graylog-system

Modifier la valeur suivante: http_external_uri = http://graylog.kube.lacave.info

Pour: http_external_uri = https://graylog.kube.lacave.info

Arrêter les pods:

    kubectl scale Statefulset lacave-graylog --replicas 0 -n graylog-system

Une fois tous les pods supprimé, démarrer les nouveaus pods:

    kubectl scale Statefulset lacave-graylog --replicas 2 -n graylog-system

L'interface de GRaylog est disponible par l'URL https://graylog.kube.lacave.info
Utiliser les informations de connexion selon les instruction donnée lors de l'installation de la charte:

    echo "User: admin"
    echo "Password: $(kubectl get secret --namespace graylog-system lacave-graylog -o "jsonpath={.data['graylog-password-secret']}" | base64 --decode)"

Créer les inputs suivants:

    gelf-tcp: port 12222
    gelf-udp: port 12231
    beats: port 5061

### Mise à jour de Graylog
Pour mettre à jour Graylog, modifier la section suivante du fichier resources/journalisation/graylog/graylog-helm-values.yaml

    graylog:
    image:
        repository: graylog/graylog:4.0.0-beta.3-1

Mettre à jour la charte avec la commande suivante:

    helm upgrade --namespace graylog-system -f resources/journalisation/graylog/graylog-helm-values.yaml lacave-graylog stable/graylog
Une fois graylog en route, pour pouvoir accéder à l'interface web en https, on doit modifier le configmap et redémarrer les pods.
Lancer la commande suivante pour modifier le configmap:

    kubectl edit configmap lacave-graylog -n graylog-system

Modifier la valeur suivante: http_external_uri = http://graylog.kube.lacave.info
Pour: http_external_uri = https://graylog.kube.lacave.info

Arrêter les pods:

    kubectl scale Statefulset lacave-graylog --replicas 0 -n graylog-system

Une fois tous les pods supprimé, démarrer les nouveaus pods:

    kubectl scale Statefulset lacave-graylog --replicas 2 -n graylog-system

# Visibilité
## Jaeger tracing
On utilise l'opérateur Jaeger: https://www.jaegertracing.io/docs/1.20/operator/
### Opérateur
Installer l'opérateur:

    kubectl create namespace observability
    kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing.io_jaegers_crd.yaml
    kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
    kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
    kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml
    kubectl create -n observability -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/operator.yaml

Activer les rôles pour avoir une portée sur tout le cluster.

    kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role.yaml
    kubectl create -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role_binding.yaml

On peut vérifier que l'opérateur est bien fonctionnel.

    kubectl get deployment -n observability
    NAME              READY   UP-TO-DATE   AVAILABLE   AGE
    jaeger-operator   1/1     1            1           117s

### Installation de Jaeger
Voici les étapes:

Créer un secret contenant l'identifiant et le mot de passe pour se connecter à Elasticsearch.

    kubectl create secret generic jaeger-es-secret --from-literal=ES_PASSWORD=$(kubectl get secret kube-lacave-elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' -n elastic-system | base64 -d) --from-literal=ES_USERNAME=elastic -n observability

Copier le secret contenant le certificat de Elasticsearch dans le namespace observabitility

    kubectl get secret kube-lacave-elasticsearch-es-http-certs-public --namespace=elastic-system -oyaml | grep -v '^\s*namespace:\s' | kubectl apply --namespace=observability -f -

Installer Jaeger:

    kubectl create -f resources/jaeger/lacave-jaeger-manifest.yaml

Un ingress est créé automatiquement par le manifest.
On peut accéder à la console web par l'URL https://jaeger.kube.lacave.info
Sinon, on peut utiliser le port forward    

    kubectl port-forward svc/lacave-jaeger-query -n observability 16686:16686

L'URL est alors http://localhost:16686


### Ajout de la source de données dans Grafana
On peut utiliser grafana pour faire des tableaux de bords pour exploiter les données recueillis par Jaeger.

    Se connecter à Grafana
    Dans le menu de Configuration -> Datasource.
    Cliquer Add Datasource
    Choisir Jaeger
    Entrer les informations suivantes:
        Name: Jaeger
        HTTP:
            URL: http://lacave-jaeger-query.observability.svc:16686
            Access: Server
    Cliquer Save and Test

## Weavescope 
Il n'est pas facile de bien voir l'interaction entre les différents pod d'un cluster Kubernets. On peut utiliser Wavescope pour créer un interface qui permet de représenter graphiquement ces inter-connexions.

Pour instller Weavescope, utiliser la commande suivante:

    kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-version=$(kubectl version | base64 | tr -d '\n')"

Pour accéder à l'interface:

    kubectl port-forward svc/weave-scope-app 4040:80 -n weave

L'URL est alors http://localhost:4040

# Service Mesh: Istio
Cette partie décrit comment déployer le Service Mesh Istio dans le cluster.

## Pré-requis
Pour une maximum de conrôle, on doit installer les composants suivants avant de déployer Istio.

Restreindre l'exécution du ingress nginx pour pouvoir utiliser l'ingress de istio.
On va ajouter un label ingress-type sur chacun des noeuds pour avoir le ingress nginx sur lube01 et kube02 et le ingress istio sur kube03 et kube04

    kubectl label nodes kube01 kube02 ingress-type=nginx
    kubectl label nodes kube03 kube04 ingress-type=istio

Modifier le ingress nginx:

    kubectl -n ingress-nginx edit daemonset ingress-nginx-controller

Ajouter la condition ingress-type dans la partie nodeSelector comme suit et sauvegarder le fichier.

      nodeSelector:
        ingress-type: nginx
        kubernetes.io/os: linux

## Déploiement de Istio
Istio est un ensemble de composant ajouté à Kubernetes pour la gestion de service mesh.
On utilise istictl pour le déployer sur le cluster Kubernetes.
Voici les instructions pour le déployer à partir du premier noeud maitre du cluster qlkub01t:

    Installer istioctl sur le serveur de déploiement:
        cd $HOME/bin
        curl -L https://istio.io/downloadIstio | sh -
        export PATH="$PATH:$HOME/bin/istio-1.6.1/bin"
    Déployer le profil par défaut:
        istioctl install --set profile=demo

Une fois le déploiement terminé, on peut ajouter le nodeSelector dans le déploiement du ingress istio

Modifier le deployment:

    kubectl -n istio-system edit deployment istio-ingressgateway

Ajouter la section suivante dans la partie spec.template.containers[0].affinity

          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: beta.kubernetes.io/arch
                operator: In
                values:
                - amd64
                - ppc64le
                - s390x
              - key: ingress-type
                operator: In
                values:
                - istio

On peut ajouter une adresse IP au Istio Ingress Gateway.
Modifier le gateway:

    kubectl -n istio-system edit svc istio-ingressgateway

Section spec, ajouter les lignes suivantes:

    externalIPs:
    - 192.168.1.25

Choisir une adresse IP non utilisée car elle va être ajoutée au hosts qui roulent le gateway.

Pour accéder aux diverses consoles, on peut installer istio sur notre poste. L'outil istioctl va utiliser la configuration par défaut du fichier ~/.kube/config.json pour se connnecter au cluster Kubernetes.
On peut alors accéder aux consoles avec les commandes suivantes:

    istioctl dashboard ConsoleAOuvrir.
    
Les consoles disponibles sont:

    controlz    Open ControlZ web UI
    envoy       Open Envoy admin web UI
    grafana     Open Grafana web UI
    jaeger      Open Jaeger web UI
    kiali       Open Kiali web UI
    prometheus  Open Prometheus web UI
    zipkin      Open Zipkin web UI


# Troubleshooting Kubernetes

## Supprimer un namespace dans l'état Terminating
Il arrive, lorsqu'on tente de supprimer un namespace, qu'il reste en mode Terminating. Suivre la procédure suivante pour le supprimer:

Lancer une proixy vers le serveur API:

    kubectl proxy &

Lancer la commande suivante pour faire un poste sur le endpoint finalize du nampespace:

    NS=nomdunamepsaceaeffacer; kubectl get ns ${NS} -o json | jq '.spec.finalizers=[]' | curl -X PUT http://localhost:8001/api/v1/namespaces/${NS}/finalize -H "Content-Type: application/json" --data @-

## Diagnostique stockage rook-ceph

### Espace dique plein dans un pvc rook ceph

Le pire c'est de trouver. On peut monitorer les volumes directement sur les hosts Linux.

    df -h | grep rbd
    /dev/rbd0        1.0G  1024M  1.0G  100% /var/lib/kubelet/pods/a0f66ee9-2ad4-471c-88a8-ea7fb2c8e4c5/volumes/kubernetes.io~csi/pvc-4a0447ec-15f8-4232-8679-625f0f47be5a/mount
    /dev/rbd1       1014M   49M  966M   5% /var/lib/kubelet/pods/00db4f27-d730-4acf-a70a-d12c26f6aa18/volumes/kubernetes.io~csi/pvc-a5583652-c700-4074-b03b-843d215a517f/mount

Si on veut savoir quel est l'image Ceph qui contient le volume, exécuter la commande suivante en utiliant le nom du pvc:

    kubectl get pv pvc-4a0447ec-15f8-4232-8679-625f0f47be5a --all-namespaces -o json | jq .spec.csi.volumeHandle
    "0001-0009-rook-ceph-0000000000000001-f616fa6e-ebd0-11ea-a3c6-2a04d02621a5"

Lancer le ceph-toolbox en utilisant l'alias créé à l'installation du pod.

    ceph-toolbox

ou

    kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath="{.items[0].metadata.name}") bash

Faire la liste des images du pool replicapool.

    rbd ls replicapool
    csi-vol-29c60437-b7ab-11ea-960f-565d092d059c
    csi-vol-2b906d13-b704-11ea-960f-565d092d059c
    csi-vol-7d5466b1-bafd-11ea-983c-8a2468105cfd
    csi-vol-7dba1fe6-bafd-11ea-983c-8a2468105cfd
    csi-vol-8f2ab8c6-bb09-11ea-983c-8a2468105cfd
    csi-vol-8f80acde-bb09-11ea-983c-8a2468105cfd
    csi-vol-bbab5eda-b7b4-11ea-960f-565d092d059c
    csi-vol-c6648a55-f3a1-11ea-a061-127158aa3afa
    csi-vol-d0a57ebb-f3a1-11ea-a061-127158aa3afa
    csi-vol-e9789cb6-f39e-11ea-a061-127158aa3afa
    csi-vol-eab8607d-f39e-11ea-a061-127158aa3afa
    csi-vol-f4d2a962-b703-11ea-960f-565d092d059c
    csi-vol-f616fa6e-ebd0-11ea-a3c6-2a04d02621a5
    csi-vol-f661f514-ebd0-11ea-a3c6-2a04d02621a5

Dans notre cas, le volume en problème correspond à l'image Ceph csi-vol-f616fa6e-ebd0-11ea-a3c6-2a04d02621a5
On peut obtenir plus d'information sur l'image rbd avec la commande suivante:

    rbd info replicapool/csi-vol-f616fa6e-ebd0-11ea-a3c6-2a04d02621a5

Pour grossir le volume, ca se fait en deux étapes:

    1) Dans le toolbox, grossir l'image avec la commande suivante:
        rbd resize csi-vol-f616fa6e-ebd0-11ea-a3c6-2a04d02621a5 --size=2G --pool=replicapool
    2) Sur l'hôte Linux, grossir le système de fichier
        xfs_growfs /var/lib/kubelet/pods/a0f66ee9-2ad4-471c-88a8-ea7fb2c8e4c5/volumes/kubernetes.io~csi/pvc-4a0447ec-15f8-4232-8679-625f0f47be5a/mount

Il faut donc monitorer les espaces disques directement sur les hôtes Linux

### Remplacer un OSD non fonctionnels avec rook-ceph

Il peut arriver qu'on des OSD devienne irrécupérable. En principe ca ne cause pas d'arrêt de service car les données sont répliqués sur d'autres OSD. 
Voici les conditions dans laquelle c'est arrivé.
Le cluster Kubernetes a 4 noeuds dont 3 sont munis d'un disque disponible pour CEPH. 

    osd.0 kube03
    osd.1 kube04
    osd.2 kube02

L'OSD corrompu est le osd.0 dans cet exemple.

Arrêter l'opérateur rook-ceph

    kubectl scale deployment -n rook-ceph rook-ceph-operator --replicas 0

Supprimer le déploiement de l'OSD corrompu du serveur Kubernetes

    kubectl delete deployment rook-ceph-osd-0 -n rook-ceph

Pour rendre le disque disponible à nouveau ou pour récupérer un disque contenant déjà des données, il faut effacer son contenu en se connectant par ssh sur le serveur kube01.
Identifier le device associé au nouveau disque, dans mon cas /dev/sdb, et lancer la commande suivante: 

    DISK="/dev/sdb"
    # Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)
    # You will have to run this step for all disks.
    sgdisk --zap-all $DISK
    # Clean hdds with dd
    dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync status=progress

Un fois le nouveau disque disponible, on peut supprimer l'ancien OSD:
Se connecter dans le pod ceph-toolbox:

    kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath="{.items[0].metadata.name}") bash

Exécuter les commandes suivantes pour supprimer l'OSD de la configuration de CEPH

    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# OSD=0
    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# ceph osd down osd.${OSD}
    osd.0 is already down. 
    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# ceph osd out osd.${OSD}
    osd.0 is already out. 
    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# ceph osd crush remove osd.${OSD}
    removed item id 0 name 'osd.0' from crush map
    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# ceph auth del osd.${OSD}
    updated
    [root@rook-ceph-tools-67788f4dd7-rvvb9 /]# ceph osd rm osd.${OSD}
    removed osd.0    

On peut surveiller l'avancement de la réplication avec la commande suivante:

    watch ceph health

Redémarrer l'opérateur rook-ceph

    kubectl scale deployment -n rook-ceph rook-ceph-operator --replicas 1

### Crash log
Le journaux des services qui pont plantés sont contenu dans des crash logs. On peut les consulter et les archivés lorsqu'il ne sont plus d'actualité. Les journaux de plantages non archivés mettent le cluster en alerte HEALTH_WARN. En les archivant on peut remettre l'état du cluster en HEALTH_OK

Pour accéder au journaux, lancer ceph-toolbox

Pour lister les journaux:

    ceph crash ls
    2020-09-28_15:30:43.217140Z_3bfcdf74-ed54-45ba-8e53-fb9460b735a6  osd.0

Pour consulter un journal:

    ceph crash info 2020-09-28_15:30:43.217140Z_3bfcdf74-ed54-45ba-8e53-fb9460b735a6

Pour archiver une entrée de journal:

    ceph crash archive 2020-09-28_15:30:43.217140Z_3bfcdf74-ed54-45ba-8e53-fb9460b735a6

Pour tout archivé les entrées de journaux:

    ceph crash archive-all

### Corrgier PG damaged et pg inconsistent
Il peut arriver, après un redémarrage forcé, que le cluster se retrouve en erreur avec le message suivant:

    [ERR] PG_DAMAGED: Possible data damage: 1 pg inconsistent

Pour connaitre quel PG est en erreur, lancer le ceph-toolbox

    ceph-toolbox

Lancer la commande suivante:

    ceph health detail
    HEALTH_ERR 1 scrub errors; Possible data damage: 1 pg inconsistent
    [ERR] OSD_SCRUB_ERRORS: 1 scrub errors
    [ERR] PG_DAMAGED: Possible data damage: 1 pg inconsistent
        pg 1.a is active+clean+inconsistent, acting [2,0,1]

Pour corriger l'erreur, dans ce cas avec le PG 1.a, lancer la commande suivante:

    ceph pg repair 1.a
        instructing pg 1.a on osd.2 to repair

On peut surveiller l'état du clueter avec la commande suivante:

    watch ceph health detail

Lorsque la tâche de réparation se termin, l'état du clueter devrait être:

    HEALTH_OK
    
### Mise à jour de l'opérateur rook-ceph et du cluster ceph
Pour mettre à jour l'opérateur et le cluster...
S'assurer que le cluster en en bonne santé et que tous les osd sont disponibles:
Lancer le ceph-toolbox
Obtenir l'état du cluster:

    ceph health
    HEALTH_OK

Obtenir l'état des osd:

    ceph osd tree
    ID  CLASS  WEIGHT   TYPE NAME        STATUS  REWEIGHT  PRI-AFF
    -1         0.97357  root default                              
    -9         0.22829      host kube01                           
    3    hdd  0.22829          osd.3        up   1.00000  1.00000
    -7         0.29050      host kube02                           
    2    hdd  0.29050          osd.2        up   1.00000  1.00000
    -3               0      host kube03                           
    -5         0.45479      host kube04                           
    0    hdd  0.45479          osd.0        up   1.00000  1.00000    

#### Mettre à jour l'opérateur
Pour mettre à jour l'opérateur, on doit modifier le numéro de version dans le manifest qui a été utilisé pour l'installation du cluster.
Dans notre cas, le fichier resources/rook/operator.yaml. Modifier le numéro de version dans la section suivante:

    spec:
      serviceAccountName: rook-ceph-system
      containers:
      - name: rook-ceph-operator
        image: rook/ceph:v1.3.11

Déployer ensuite l'opérateur

    kubectl apply -f resources/rook/operator.yaml

Surveiller le déploiement en utilisant la commande suivante et attendre que ca se stabilise:

    watch kubectl get pod -n rook-ceph
    NAME                                               READY   STATUS      RESTARTS   AGE
    csi-cephfsplugin-provisioner-6748bb9646-n64lw      5/5     Running     0          18h
    csi-cephfsplugin-provisioner-6748bb9646-wzkt6      5/5     Running     0          18h
    csi-cephfsplugin-vn4xq                             3/3     Running     3          18h
    csi-cephfsplugin-w725z                             3/3     Running     0          18h
    csi-cephfsplugin-xs7tw                             3/3     Running     0          18h
    csi-cephfsplugin-z8mgc                             3/3     Running     0          18h
    csi-rbdplugin-6225v                                3/3     Running     3          18h
    csi-rbdplugin-j57n9                                3/3     Running     0          18h
    csi-rbdplugin-jgwbp                                3/3     Running     0          18h
    csi-rbdplugin-provisioner-78db9f787f-4sclm         6/6     Running     0          18h
    csi-rbdplugin-provisioner-78db9f787f-b5j9q         6/6     Running     0          18h
    csi-rbdplugin-tmqbr                                3/3     Running     1          18h
    rook-ceph-crashcollector-kube01-7d5dddbf67-94rqf   1/1     Running     0          20h
    rook-ceph-crashcollector-kube02-54749c9d48-2x7vk   1/1     Running     0          18h
    rook-ceph-crashcollector-kube03-6cb68f6c5c-sg8kh   1/1     Running     0          24h
    rook-ceph-crashcollector-kube04-69c5bc94c4-rm4m6   1/1     Running     1          3h38m
    rook-ceph-mgr-a-754fbc96c8-q2tkd                   1/1     Running     0          24h
    rook-ceph-mon-dd-7c9fb48cf9-mrt4w                  1/1     Running     0          24h
    rook-ceph-mon-de-6885788fcf-795n8                  1/1     Running     0          19h
    rook-ceph-mon-df-6779744bb-vzqwh                   1/1     Running     0          3h17m
    rook-ceph-operator-8d9bf87c-c9gbg                  1/1     Running     0          3h20m
    rook-ceph-osd-0-5d557c6965-rc7t5                   1/1     Running     0          3h7m
    rook-ceph-osd-2-f478659bf-sq7cv                    1/1     Running     0          3h18m
    rook-ceph-osd-3-7b94786cb5-m27tn                   1/1     Running     0          20h
    rook-ceph-osd-prepare-kube01-pl2vh                 0/1     Completed   0          139m
    rook-ceph-osd-prepare-kube02-n2b2p                 0/1     Completed   0          139m
    rook-ceph-osd-prepare-kube03-fb6qw                 0/1     Completed   0          139m
    rook-ceph-osd-prepare-kube04-ffq8l                 0/1     Completed   0          138m
    rook-ceph-tools-67788f4dd7-hkrnq                   1/1     Running     0          18h
    rook-discover-f8rv8                                1/1     Running     0          18h
    rook-discover-ggp2b                                1/1     Running     0          18h
    rook-discover-lc7fl                                1/1     Running     136        18h
    rook-discover-trvxn                                1/1     Running     0          18h    

#### Mise à jour du cluster
Pour la mise à jour du cluster, modifier la section suivante manifest utilisé pour créer le cluster. Dans notre cas, resources/rook/cluster.yaml

    apiVersion: ceph.rook.io/v1
    kind: CephCluster
    metadata:
    name: rook-ceph
    namespace: rook-ceph
    spec:
    cephVersion:
        # The container image used to launch the Ceph daemon pods (mon, mgr, osd, mds, rgw).
        # v13 is mimic, v14 is nautilus, and v15 is octopus.
        # RECOMMENDATION: In production, use a specific version tag instead of the general v14 flag, which pulls the latest release and could result in different
        # versions running within the cluster. See tags available at https://hub.docker.com/r/ceph/ceph/tags/.
        # If you want to be more precise, you can always use a timestamp tag such ceph/ceph:v14.2.5-20190917
        # This tag might not contain a new Ceph version, just security fixes from the underlying operating system, which will reduce vulnerabilities
        image: ceph/ceph:v15.2.4

Déployer le manifest:

    kubectl apply -f resources/rook/cluster.yaml

Attendre que le processus se fasse. Ca peut être très long car chaque composant va se mettre à jour progessivement sans interruption de service.

## Réseau
Calico (réseau):

    export ETCD_KEY_FILE=/etc/calico/certs/key.pem
    export ETCD_CERT_FILE=/etc/calico/certs/cert.crt 
    export ETCD_CA_CERT_FILE=/etc/calico/certs/ca_cert.crt
    export ETCD_ENDPOINTS=https://10.3.0.1:2379,https://10.3.0.2:2379,https://10.3.0.3:2379

    Obtenir les noeuds Calico
    calicoctl get nodes -o yaml
 
# Flatcar Linux
J'utilise le CD d'installation de Flatcar pour provisionner manuellement les noeuds.
La première étape est de graver sur un CD/DVD ou une clé USB l'ISO de Flatcat https://docs.flatcar-linux.org/os/booting-with-iso/

La deuxième étape est de créer les fichiers d'intialisation pour les 4 noeuds. On créé ces fichiers sur le serveur de provisionning.
Voici la strcture du fichier. 

    kubeXX-ignition.json
    {
    "ignition": {
        "version": "2.2.0"
    },
    "passwd": {
        "users": [
        {
            "name": "root",
            "sshAuthorizedKeys": [
            "Copier Le contenue du fichier .ssh/id_rsa.pub de l'utilisateur principal du serveur de provisioning"
            ]
        }
        ]
    },
    "networkd": {
        "units": [
        {
            "contents": "[Match]\nName=eno1\n\n[Network]\nAddress=192.168.1.XX/24\nGateway=192.168.1.1\nDNS=192.168.1.10",
            "name": "00-eno1.network"
        }
        ]
    },
    "storage": {
        "files": [{
        "filesystem": "root",
        "path": "/etc/hostname",
        "mode": 420,
        "contents": { "source": "data:,kubeXX" }
        }]
    }

Faire un fichier par noeud (kube01, kube02 et kube03)
Sur chacun des noeuds:

    Démarrer le serveur en utilisant le CD/DVD ou la clé USB
    Télécharger le ficher d'initilisation du serveur en utiliant scp. Ex:
        scp utilisateurprincipal@serveur.provisioning:kubeXX-ignition.json .
    Lancer l'intialisation du serveur
        sudo flatcar-install -d /dev/sda -i kubeXX-ignition.json
    Enlver le CD/DVD ou la clé USB et redémarrer le serveur.
    Le redémarrer une seconde fois s'il n'a pas la bonne adresse IP.

# Création des noeuds
Les étapes suivantes doivent être exécuté à partir du serveur Ansible principal.

Se connecter sur le serveur contrôleur Ansible en tant que l'utilisateur dont la clé RSA pour SSH a été ajouté dans le authorized_keys des usagers root des serveurs CoreOS.

Faire le checkout du projet et des sous-projets dans un rpertoire de travail:

    git clone --recursive https://github.com/elfelip/kube-lacave.git

Dans ce projet on utilise 3 noeuds:

    kube01: premier master
    kube02: noeud d'exécution d'application
    kube03: deuxième master

## Ajout du certifact de du root CA dans les trust stores des noeuds
Pour que docker soit en mesure de se connecter en https sur les services qui ont des certificats émis par notre PKI interne, on doit faire les opérations suivantes sur tous les noeuds:

    scp resources/cert/lacave-root.pem root@kube01:/etc/ssl/certs
    ssh root@kube01 update-ca-certificates
    scp resources/cert/lacave-root.pem root@kube02:/etc/ssl/certs
    ssh root@kube02 update-ca-certificates
    scp resources/cert/lacave-root.pem root@kube03:/etc/ssl/certs
    ssh root@kube03 update-ca-certificates

Actuellement, l'authentification OpenID Connect est ajouté dans la configuration du cluster.
Pour que le déploiement puisse fonctionner, on doit copier le certificat lacave-root.pem dans les répertopires /etc/kubernetes/ssl de chacun des noeuds du cluster.

    ssh root@kube01 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube01:/etc/kubernetes/ssl
    ssh root@kube02 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube02:/etc/kubernetes/ssl
    ssh root@kube03 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube03:/etc/kubernetes/ssl
