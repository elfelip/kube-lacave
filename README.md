# Projet cluster Kubernetes
Ce projet permet de créer un cluster Kubernetes sur CoreOS/Flatcar

# Création des noeuds
Les étapes suivantes doivent être exécuté à partir du serveur Ansible principal.

Se connecter sur le serveur contrôleur Ansible en tant que l'utilisateur dont la clé RSA pour SSH a été ajouté dans le authorized_keys des usagers root des serveurs CoreOS.

Faire le checkout du projet et des sous-projets dans un rpertoire de travail:

    git clone --recursive https://github.com/elfelip/kube-lacave.git

Dans ce projet on utilise 3 noeuds:
    kube01.lacave: premier master
    kube02.lacave: noeud d'exécution d'application
    kube03.lacave: deuxième master

Actuellement, l'authentification OpenID Connect est ajouté dans la configuration du cluster.
Pour que le déploiement puisse fonctionner, on doit copier le certificat lacave-root.pem dans les répertopires /etc/kubernetes/ssl de chacun des noeuds du cluster.

    ssh root@kube01 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube01:/etc/kubernetes/ssl
    ssh root@kube02 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube02:/etc/kubernetes/ssl
    ssh root@kube03 mkdir -p /etc/kubernetes/ssl
    scp resources/cert/lacave-root.pem root@kube03:/etc/kubernetes/ssl

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
    

# Installer et clonfigurer kubectl sur le serveur Ansible/Jenkins
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

    kubectl describe secret admin-user-token-f85z5 -n kubernetes-dashboard
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
L'outil kubectl est installé et configuré automatiquement sur les deux noeuds maitres du cluster Kubernetes: qlkub01t et qlkub02t pour l'utilisateur root.

Il est possible de l'installer sur une autre machine. Pour configurer la connexion et l'authentification du client, on peut récupérer les informations qui sont dans le fichier config du répertoire /root/.kube des serveurs maitres. On doit modifier le paramètre server en fonction de l'emplacement réseau. On peut utiliser n'importe quel des noeuds maitre pour se connecter à l'API (qlkub01t ou qlkub02t).

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: LS0tLS1...
        server: https://qlkub01t.laboinspq.qc.ca:6443
    name: labo.inspq
    contexts:
    - context:
        cluster: labo.inspq
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

    kubectl --context=kubernetes-admin@labo.inspq

# Gestion des certificats

## Installation cert-manager
Cert Manager peut être installé par kubespray mais la version déployé semble limité.
On peut en installer un version plus récente avec la commande suivante:
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.15.0/cert-manager.yaml

## Création de l'émetteur de certificat SelfSigned pour lacave
Cert-manager peut créer des certificats en utilisant une autoirité de certification selfsigned. Pour créer cet émetteur au niveau du cluster, exécuter le manifest suivant:

    kubectl create -f resources/cert/root-ca-cert-manager.yml

## Configuration OpenID Connect

Pour faire l'authentification des utilisateurs sur le cluster on install un serveur Keycloak.
Lancer le manifest suivant pour créer le serveur Keycloak.

    kubectl create -f resources/keycloak/keycloak-deployment.yaml

S'assurer que le DNS contient une entrée login.kube.lacave qui pointe vers les adresses IP des noeuds du cluster.

Accéder ensuite au serveur Keycloak: https://login.kube.lacave/auth/
S'authentifier en tant que l'utilisateur admin/admin
Dans le realm master créer le client suivant:
    Client ID: kubeapi
    Root URL: http://localhost:8000
    Client Protocol: openid connect
    Access type: Confidential
    Prendre en note de Client Secret de l'oinglet Credentials.

Ajouter dans l'onglet mappers, cliquer Add builtin, sélectionner groups et cliquer Add selected

Dans le menu Roles: Créer le rôle cluster-admin

Dans le menu Users: Sélectionner l'utilisateur Admin, dans l'onglet Role Mappings, lui assigner le rôle cluster-admin.

Installer Kubelogin
    curl -LO https://github.com/int128/kubelogin/releases/download/v1.19.0/kubelogin_linux_amd64.zip
    unzip kubelogin_linux_amd64.zip
    chmod a+x kubelogin
    cp kubelogin ~/bin

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
            command: kubelogin
            args:
            - get-token
            - --oidc-issuer-url=https://login.kube.lacave/auth/realms/master
            - --oidc-client-id=kubeapi
            - --oidc-client-secret=client-secret-de-kube-api

Pour utililiser ce profil:

    kubectl --context oidc@kube.lacave get nodes

S'authentifier en tant qu'admin dans Keycloak si vous ne l'êtes pas déjà.

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

## Dépot Nexus
Pour entreposer des artefacts, dont les images de conteneurs, on utilise un serveur Nexus.
Pour le déployer, utiliser le manifest suivant:

    kubectl apply -f resources/nexus/nexus-deployment.yml

Le serveur nexus est accessible par l'URL https://nexus.lacave
Le dépôt d'images de conteneurs est docker.lacave

## Proxy Open ID Connect pour la Dashboard
On créé un proxy Keycloak qui permet d'accéder au tableau de bord Kubernetes avec une Authentificaiton OpenID Connect.

La première étape est de créer un image qui accepte les certificats auto-signé de notre environnement.

    Se déplacer dans le répertoire resources/keycloak/keycloak-proxy
    Exécuter le script: build.sh

On peut ensuite déployer le manifest qui crée le proxy:

    kubectl apply -f resources/keycloak/oidc-dashboard-proxy.yaml
    
## Déploiement d'une première application
On peut déployer un application en utilisant kubectl. Voici un exemple qui déploie 3 pods ngnix:

Déployer les pods

    kubectl apply -f resources/nginx-deployment.yaml

Voir les pods:

    kubectl get pods
    NAME                                READY   STATUS    RESTARTS   AGE
    nginx-deployment-54f57cf6bf-2p985   1/1     Running   0          54s
    nginx-deployment-54f57cf6bf-h95gn   1/1     Running   0          54s
    nginx-deployment-54f57cf6bf-v5fp2   1/1     Running   0          54s

Voir le déploiement:

    kubectl describe deployments
    Name:                   nginx-deployment
    Namespace:              default
    CreationTimestamp:      Tue, 31 Dec 2019 10:14:45 -0500
    Labels:                 app=nginx
    Annotations:            deployment.kubernetes.io/revision: 1
                            kubectl.kubernetes.io/last-applied-configuration:
                            {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"labels":{"app":"nginx"},"name":"nginx-deployment","namespace":"d...
    Selector:               app=nginx
    Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
    StrategyType:           RollingUpdate
    MinReadySeconds:        0
    RollingUpdateStrategy:  25% max unavailable, 25% max surge
    Pod Template:
    Labels:  app=nginx
    Containers:
    nginx:
        Image:        nginx:1.7.9
        Port:         80/TCP
        Host Port:    0/TCP
        Environment:  <none>
        Mounts:       <none>
    Volumes:        <none>
    Conditions:
    Type           Status  Reason
    ----           ------  ------
    Available      True    MinimumReplicasAvailable
    Progressing    True    NewReplicaSetAvailable
    OldReplicaSets:  <none>
    NewReplicaSet:   nginx-deployment-54f57cf6bf (3/3 replicas created)
    Events:
    Type    Reason             Age    From                   Message
    ----    ------             ----   ----                   -------
    Normal  ScalingReplicaSet  2m14s  deployment-controller  Scaled up replica set nginx-deployment-54f57cf6bf to 3

Augmenter le nombre de pods

    kubectl scale deployment.v1.apps/nginx-deployment --replicas=10
    deployment.apps/nginx-deployment scaled

Voir le service:

    kubectl describe services ngnix-service
    Name:              ngnix-service
    Namespace:         default
    Labels:            <none>
    Annotations:       kubectl.kubernetes.io/last-applied-configuration:
                        {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"name":"ngnix-service","namespace":"default"},"spec":{"ports":[{"port":93...
    Selector:          app=nginx
    Type:              ClusterIP
    IP:                10.233.61.224
    Port:              <unset>  9376/TCP
    TargetPort:        80/TCP
    Endpoints:         10.233.105.7:80,10.233.127.6:80,10.233.86.9:80
    Session Affinity:  None
    Events:            <none>
    
Accéder à l'application

    [ansible@qlkub01t resources]$ curl http://10.233.61.224:9376
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

Le déploiment inclus aussi une configuration Ingress permettant d'y accéder de l'extérieur du cluster:

    curl -H "Host: kubenginx.laboinspq.qc.ca" http://qlkub01t.laboinspq.qc.ca
    curl -H "Host: kubenginx.laboinspq.qc.ca" http://qlkub02t.laboinspq.qc.ca
    curl -H "Host: kubenginx.laboinspq.qc.ca" http://qlkub03t.laboinspq.qc.ca
    curl -H "Host: kubenginx.laboinspq.qc.ca" http://qlkub04t.laboinspq.qc.ca

Si l'entré a été ajouté au DNS, on peut aussi y accéder par l'URL http://kubenginx.laboinspq.qc.ca

Pour supprimer le déploiement

    kubectl delete -f nginx-deployment.yaml
    deployment.apps "nginx-deployment" deleted
    service "ngnix-service" deleted
    ingress.networking.k8s.io "ingress-nginx" deleted

# Configuration DNS

    On créé un l'entre DNS kubecluster.laboinspq.qc.ca pour les 4 adresses IP des noeuds du cluster.

    Le services peuvent ensuite être publié en créant une entré de type cname. Pour l'application exemple, kubenginx on créé l'entré DNS suivante dans la zone laboinspq.qc.ca:
    kubenginx.laboinspq.qc.ca CNAME kubecluster.laboinspq.qc.ca


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