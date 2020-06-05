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
Le fichier de zone pour lacave est /etc/bind/lacave.db

    On créé des entres DNS pour les 3 noeuds ainsi que l'entré kube.lacave pour les 3 adresses IP des noeuds du cluster.
    kube01.lacave   IN  A   192.168.1.21
    kube02.lacave   IN  A   192.168.1.22
    kube03.lacave   IN  A   192.168.1.23
    kube.lacave.    IN  A   192.168.1.21
                    IN  A   192.168.1.22
                    IN  A   192.168.1.23

    Le services peuvent ensuite être publié en créant une entré de type cname. Pour l'application exemple, kubenginx on créé l'entré DNS suivante dans la zone lacave:
    login.kube.lacave       CNAME   kube.lacave.
    dashboard.kube.lacave   CNAME   kube.lacave.

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
            "contents": "[Match]\nName=enp3s0\n\n[Network]\nAddress=192.168.1.XX/24\nGateway=192.168.1.1\nDNS=192.168.1.10",
            "name": "00-enp3s0.network"
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
    },
    "systemd": {}
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
    kube01.lacave: premier master
    kube02.lacave: noeud d'exécution d'application
    kube03.lacave: deuxième master

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

Si la configuration par défaut du dashboard de kubespray ne suffit pas, suivre les étapes suivantes pour le faire. Dans ce cas, le manifest pour la création de l'administrateur doit être modifier pour utiliser le namespace kubernetes-dashboard au lieu de kube-system.

Se connecter sur le premier noeud master, kube01t, en tant que root ou sur le serveur Jenkins/Ansible.

Déployer la dernière version du dashboard

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc1/aio/deploy/recommended.yaml


On peut alors accéder à la console en suivante les étapes de la section Utilisation.

Si on doit supprimer le dashboard, utiliser la commande suivante:
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml

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

# Configuration OpenID Connect

Pour faire l'authentification des utilisateurs sur le cluster on install un serveur Keycloak.
Lancer le manifest suivant pour créer le serveur Keycloak.

    kubectl create -f resources/keycloak/keycloak-deployment.yaml

S'assurer que le DNS contient une entrée login.kube.lacave qui pointe vers les adresses IP des noeuds du cluster.

Accéder ensuite au serveur Keycloak: https://login.kube.lacave/auth/
S'authentifier en tant que l'utilisateur admin/admin

## Création du client
Dans le realm master créer le client suivant:
    Client ID: kubeapi
    Root URL: http://localhost:8000
    Client Protocol: openid connect
    Access type: Confidential
    Ajouter le redirect uri: https://dashboard.kube.lacave
    Ajouter l'origin: https://dashboard.kube.lacave
    Prendre en note de Client Secret de l'oinglet Credentials.

Ajouter dans l'onglet mappers, cliquer Add builtin, sélectionner groups et cliquer Add selected
Dans l'onglet Roles, Ajouter le rôle kubernetes-user

## Création du scope de client
Pour que Keycloak configure l'audience dans le jeton d'authentification, on doit créer le client scope suivant:

    Dans le menu Client Scope cliquer sur le bouton Create.
    Entrer les informations suivantes et cliquer Save:
        Name: kube-api-audience
        Description: Scope pour Kubernetes
        Protocol: openid-connect
        Display On Consent Screen: On
        Include in Token Scope: On
    Aller ensuite dans l'onglet Mappers:
    Cliquer sur Create
    Entrer les informations suivantes et cliquer Save:
        Name: kube-api-audience
        Mapper Type: Audience
        Included Client Audience: kubeapi
        Add to ID token: On
        Add to access token: On

    Dans le menu Client
    Sélectionner le client kubeapi
    Dans l'onglet Client Scope
    Ajouter le scope kube-api-audience dans Assigned Default Client Scopes



## Création du rôle de REALM pour les administrateurs du cluster

Dans le menu Roles: Créer le rôle cluster-admin et cliquer Save

Dans le menu Users: Sélectionner l'utilisateur Admin, dans l'onglet Role Mappings, lui assigner le rôle cluster-admin.

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
            - --oidc-issuer-url=https://login.kube.lacave/auth/realms/master
            - --oidc-client-id=kubeapi
            - --oidc-client-secret=client-secret-de-kube-api

Pour utililiser ce profil:

    kubectl --context oidc@kube.lacave get nodes

S'authentifier en tant qu'admin dans Keycloak si vous ne l'êtes pas déjà.

# Dépot Nexus
Pour entreposer des artefacts, dont les images de conteneurs, on utilise un serveur Nexus.
Pour le déployer, utiliser le manifest suivant:

    kubectl apply -f resources/nexus/nexus-deployment.yml

Le serveur nexus est accessible par l'URL https://nexus.lacave
Le dépôt d'images de conteneurs est docker.lacave

# Authentification au registre Docker du Nexus

Suivre les étapes suivantes pour créer un secret utilisable par Kubernetes pour s'authentifier auprès du registre Docker du serveur Nexus:
Référence: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

S'authentifier au registre Docker du Nexus si ce n'est pas déjà fait:

    docker login nexus3.inspq.qc.ca:5000

Vérifier que le ficher de config Docker pour identifier les informations d'authentification:

    cat ~/.docker/config.json 
{
	"auths": {
		"docker.lacave": {
			"auth": "LeSecretEstDansLaSauce"
		},
		"nexus3.inspq.qc.ca:5000": {
			"auth": "LeSecretEstDansLaSauce"
		},
		"https://index.docker.io/v1/": {
			"auth": "LeSecretEstDansLaSauce"
		}
	}
}

Créer le secret dans Kubernetes:

    kubectl create secret generic regcred --from-file=.dockerconfigjson=${HOME}/.docker/config.json --type=kubernetes.io/dockerconfigjson -n kube-system
Ce secret doit être créé dans chacun des Namespace qui utilise le registre privé.

## Proxy Open ID Connect pour la Dashboard

On créé un proxy Keycloak qui permet d'accéder au tableau de bord Kubernetes avec une Authentificaiton OpenID Connect.

La première étape est de créer un image qui accepte les certificats auto-signé de notre environnement.

    Se déplacer dans le répertoire resources/keycloak/keycloak-proxy
    Exécuter le script: build.sh

On peut ensuite déployer le manifest qui crée le proxy:

    kubectl apply -f resources/keycloak/oidc-dashboard-proxy.yaml

S'assurer que l'entré DNS dashboard.kube.lacave existe dans le DNS et pointe vers les adresses des noeuds du Cluster.
On peut accéder au Dashboard par l'adresse https://dashboard.kube.lacave
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
    scp resources/cert/lacave-root.pem root@kube01:/etc/ssl/certs
    ssh root@kube01 update-ca-certificates
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

# Monitoring

Pour le monitoring, on install l'opérateur Prometheus à l'aide du helm chart.

Pour l'installer, se connecter en tant que root sur le premier noeud master du cluster: qlkub01t

Installer le helm chart:

    helm install --name prometheuslabo stable/prometheus-operator

On peut avoir le statut de l'opérateur avec la commande suivante:

    kubectl --namespace default get pods -l "release=prometheuslabo"

Créer les ingress pour les consoles Grafana et Prometheus en appliquant les fichiers de déploiements suivants:

    kubectl --context=kubernetes-admin@labo.inspq apply -f resources/grafana-ingress.yml
    kubectl --context=kubernetes-admin@labo.inspq apply -f resources/prometheus-ingress.yml

Créé les entrés DNS suivantes dans la zone laboinspq.qc.ca:
    kubegrafana.laboinspq.qc.ca CNAME kubecluster.laboinspq.qc.ca
    kubeprometheus.laboinspq.qc.ca CNAME kubecluster.laboinspq.qc.ca

On peut obtenir le username/password avec les commandes suivantes:

    kubectl --context=kubernetes-admin@labo.inspq get secret prometheuslabo-grafana -o jsonpath='{.data.admin-user}' | base64 --decode
    kubectl --context=kubernetes-admin@labo.inspq get secret prometheuslabo-grafana -o jsonpath='{.data.admin-password}' | base64 --decode
    
La console Grafana est accessible à l'adresse suivante http://kubegrafana.laboinspq.qc.ca/login
La console Prometheus est accessible à l'adresse suivante http://kubeprometheus.laboinspq.qc.ca

## Ajouter des composants

On peut ajouter des composants à grafana en utilisant le CLI inclu dans le pod.
On peut donc installer le composant pie-chart en exécutant les commandes suivantes:

    À partir du serveur qlkub01t:
    helm upgrade prometheuslabo stable/prometheus-operator --set grafana.plugins[0]=grafana-piechart-panel

# Istio

Istio est un ensemble de composant ajouté à Kubernetes pour la gestion de service mesh.
On utilise istictl pour le déployer sur le cluster Kubernetes.
Voici les instructions pour le déployer à partir du premier noeud maitre du cluster qlkub01t:

    Installer les fichier istio sur le master:
        wget https://github.com/istio/istio/releases/download/1.4.3/istio-1.4.3-linux.tar.gz
        tar -zxvf istio-1.4.3-linux.tar.gz
        cd istio-1.4.3
    Déployer le profil par défaut:
        bin/istioctl manifest apply --set values.grafana.enabled=true
        This will install the default Istio profile into the cluster. Proceed? (y/N) y

Pour accéder au dashboard grafana du namespace istio:

    Lancer la commande suivantes sur votre poste de travail ou kubectl est installé et configuré:
        kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].madata.name}') 3000:3000
    Vous pouvez accéder à la console par l'URL: http://localhost:3000

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



# Troubleshooting

Calico (réseau):
    export ETCD_KEY_FILE=/etc/calico/certs/key.pem
    export ETCD_CERT_FILE=/etc/calico/certs/cert.crt 
    export ETCD_CA_CERT_FILE=/etc/calico/certs/ca_cert.crt
    export ETCD_ENDPOINTS=https://10.3.0.1:2379,https://10.3.0.2:2379,https://10.3.0.3:2379

    Obtenir les noeuds Calico
    calicoctl get nodes -o yaml
 
 

# Monitoring
On utilise Prometheus et Grafana qui ont été déployé en même temps que le composant istio.
On ajoute certains composants comme le node exporter permettant de monitorer les noeuds du cluster Kubernetes.

Créer le namespace
    kubectl apply - resources/monitoring/monitoring-deployment.yaml

Installer le node exporter
    helm install -n monitoring node-exporter stable/prometheus-node-exporter