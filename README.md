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

    Le services peuvent ensuite être publié en créant une entré de type cname. Pour l'application exemple, kubenginx on créé l'entré DNS suivante dans la zone lacave:
    login.kube.lacave.info       CNAME   kube.lacave.info
    dashboard.kube.lacave.info   CNAME   kube.lacave.info

# Création du PKI
Afin de faciliter le création de certificats self-signed, on se cré un petite infrastructure à clé publique sur le serveur de provisionning.
Référence: https://pki-tutorial.readthedocs.io/en/latest/simple/index.html
La chaine de confiance ainsi que les clés de ce PKI sont incluse dans le projet GIT.

# Préparation des noeuds
La première étape est d'installer un système d'exploitation sur les noeuds physiques ou virtuel.
Pour ce projet on a choisi Flatcar Container Linux qui est un fork de CoreOS suite à son achat par RedHat. On aurait aussi pu le faire avec Fedora CoreOS mais avec leur abandon de Docker, ca redait le passage de CoreOS vers Fedora un peu plus complexe.

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

# Installation du Cluster

S'assurer d'être dans le répertoire kube-lacave et lancer le playbook de déploiement du cluster:

    ansible-playbook -i inventory/lacave/inventory.ini kubespray/cluster.yml

Assigner un rôle au noeud kube02:
    kubectl label node kube02 node-role.kubernetes.io/worker=worker

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

    kubectl describe secret -n kube-system admin-user-token-f85z5
    Name:         admin-user-token-f85z5
    Namespace:    kubernetes-dashboard
    Labels:       <none>
    Annotations:  kubernetes.io/service-account.name: admin-user
                kubernetes.io/service-account.uid: ab8b5470-6884-406d-ab30-20dd0967ab7e

    Type:  kubernetes.io/service-account-token

    Data
    ====
    ca.crt:     1025 bytes
    namespace:  20 bytes
    token:      eyJhbG...


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
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml

## Création de l'émetteur de certificat SelfSigned pour lacave
Cert-manager peut créer des certificats en utilisant une autoirité de certification selfsigned. Pour créer cet émetteur au niveau du cluster, exécuter le manifest suivant:

    kubectl create -f resources/cert/root-ca-cert-manager.yml

# Stockage
Après l'installation de Kubespray avec l'inventaire actuel, seul le stockage local est disponible. Ce stockage n'est ni portable d'un noeud à l'autre ni redontant. 

## Stockage Ceph avec l'opérateur Rook
Pour ajouter la redondance au niveau du stokcage on va installer l'opérateur CEPH rook: https://rook.io

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
        kubectl get secret -n rook-ceph rook-ceph-dashboard-password -o json | jq -r .data.password | base64 -d
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

    pgo create cluster testcluster --storage-config=rook --pgbackrest-storage-config=rook
    created cluster: testcluster
    workflow id: e0a1bb2b-8ff0-4a65-90a0-45f0d00477c7
    database name: testcluster
    users:
            username: testuser password: UnMotDePasseLongEtComplexeGenereAutomatiquementParLOperateur

## Installer pgadmin4

Sur Ubuntu:
    # Ajouter le clé du repository
    curl https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add
    # Ajouter le repository
    sudo sh -c 'echo "deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list && apt update'
    # Installer pgadmin4
    sudo apt install pgadmin4-desktop

Pour se connecter sur la BD:
    # Lancer un port-forward
    kubectl -n pgo port-forward svc/testcluster 5432:5432 &
    # Se connecter sur la BD avec pgadmin à l'adresse localhost:5432
    # On peut obtenir le nom d'utilisateur avec la commande suivante:
    kubectl get secret -n pgo testcluster-testuser-secret -o json | jq -r .data.username | base64 -d
    # On peut obtenir le mot de passe avecla commande suivante:
    kubectl get secret -n pgo testcluster-testuser-secret -o json | jq -r .data.password | base64 -d

# Configuration OpenID Connect

## Création de la base de données
Pour mettre les données de Keycloak, on utilise un cluster Postgres créé par l'opérateur Crunchy

    # Créer le namespace
    pgo create namespace kcdatabases
    # Créer le cluster de base de données et la base de données de Keycloak
    pgo create cluster loginlacavecluster -n kcdatabases --database=keycloak --username=keycloak --password=keycloak --storage-config=rook --pgbackrest-storage-config=rook

## Créer l'image Keycloak avec les scripts supportant le clustering.
Pour mettre Keycloak en cluster, on utilise le protocol JDBC_PING pour le Jgroups. Pour ce faire, des scripts doivent être ajouté à l'image de base de Keycloak. Ces scripts sont inclus dans le présen projet, pour créer l'image Keycloak, lancer les commmandes suivantes:

    docker build --tag docker.lacave.info/keycloak:10.0.2 resources/keycloak/image/
    docker push docker.lacave.info/keycloak:10.0.2

## Installation de Keycloak
Pour faire l'authentification des utilisateurs sur le cluster on install un serveur Keycloak.
Lancer le manifest suivant pour créer le serveur Keycloak.

    kubectl create -f resources/keycloak/keycloak-deployment.yaml

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

Vérifier l'état nes noeuds:
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
        gir checkout master
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

## Node exporter
On utilise Prometheus et Grafana qui ont été déployé en même temps que le composant istio.
On ajoute certains composants comme le node exporter permettant de monitorer les noeuds du cluster Kubernetes.

Créer le namespace
    kubectl apply - resources/monitoring/monitoring-deployment.yml

Ajouter le repo stable
    helm repo add stable https://kubernetes-charts.storage.googleapis.com/
Installer le node exporter
    helm install -n monitoring node-exporter stable/prometheus-node-exporter

## Configuration de Grafana

On peut ajouter un dashboard pour le node exporter: https://grafana.com/api/dashboards/1860/revisions/20/download


# Troubleshooting Kubernetes

Calico (réseau):
    export ETCD_KEY_FILE=/etc/calico/certs/key.pem
    export ETCD_CERT_FILE=/etc/calico/certs/cert.crt 
    export ETCD_CA_CERT_FILE=/etc/calico/certs/ca_cert.crt
    export ETCD_ENDPOINTS=https://10.3.0.1:2379,https://10.3.0.2:2379,https://10.3.0.3:2379

    Obtenir les noeuds Calico
    calicoctl get nodes -o yaml
 
 

