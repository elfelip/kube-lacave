# Projet cluster Kubernetes INSPQ
Ce projet permet de créer un cluster Kubernetes sur CoreOS

# Création des noeuds
Les étapes suivantes doivent être exécuté à partir du serveur Ansible principal (Serveur Jenkins)

Se connecter sur le serveur contrôleur Ansible en tant que l'utilisateur dont la clé RSA pour SSH a été ajouté dans le authorized_keys des usagers root des serveurs CoreOS.

Faire le checkout du projet et des sous-projets dans un rpertoire de travail:

    git clone --recursive https://github.com/elfelip/kube-lacave.git


S'assurer d'être dans le répertoire cluster-kubernetes et lancer le playbook de déploiement du cluster:

    ansible-playbook -i inventory/lacave/inventory.ini kubespray/cluster.yml

# Configurer Ansible
Installer les pré-requis pour le module Ansible k8s. Ces instructions sont pour Ubuntu 18.04.

	sudo apt install python3-kubernetes
	pip3 install openshift --user


# Installer et clonfigurer kubectl sur le serveur Ansible/Jenkins
Pour faciliter les opérations, on peut installer et configurer kubectl sur le serveur Jenkins en effectualnt les étapes suivantes:

Installer kubectl

L'outil kubectl a été installé et configuré par le playbook de déploiment du Cluster

Tester la connexion

    kubectl get pods -n kube-system
    NAME                                       READY     STATUS    RESTARTS   AGE
    calico-kube-controllers-7758fbf657-6gd9k   1/1       Running   0          13m
    ...


# Déploiement du Dashboard

Pour le moment, la configuration du Kubespray ne déploie pas le dashboard Kubernetes. Suivre les étapes suivantes pour le faire.

Se connecter sur le premier noeud master, qlkub01t, en tant que root ou sur le serveur Jenkins en tant que jenkins.

Déployer la dernière version du dashboard

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-rc1/aio/deploy/recommended.yaml

Créer l'utilisateur Admin en utilisant le fichier de déploiement du sous-répertoire resource du projet GIT cluster-kubernetes utilisé pour le déploiement.

    kubectl apply -f resources/dashboard-adminuser.yml

Lui donner le rôle cluster-admin

    kubectl apply -f resources/admin-role-binding.yml


On peut alors accéder à la console en suivante les étapes de la section Utilisation.

Si on doit supprimer le dashboard, utiliser la commande suivante:
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml

# Utilisation

## Accéder à la console
Pour obtenir le jeton d'authentification, lancer les commandes suivantes à partir du premier noeud master du cluster en tant que root:

    kubectl get secret -n kubernetes-dashboard
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

    En LABO:
    https://kube01.lacave:6443/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/#!/login
    Utiliser le token de l'étape précédente

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

# Authentification au registre Docker du Nexus

Suivre les étapes suivantes pour créer un secret utilisable par Kubernetes pour s'authentifier auprès du registre Docker du serveur Nexus:
Référence: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/

S'authentifier au registre Docker du Nexus si ce n'est pas déjà fait:

    docker login nexus3.inspq.qc.ca:5000

Vérifier que le ficher de config Docker pour identifier les informations d'authentification:

    cat ~/.docker/config.json 
{
	"auths": {
		"https://nexus3.inspq.qc.ca:5000": {
			"auth": "LeSecretEstDansLaSauce"
		},
		"nexus3.inspq.qc.ca:5000": {
			"auth": "LeSecretEstDansLaSauce"
		},
		"nexus3.laboinspq.qc.ca:5000": {
			"auth": "LeSecretEstDansLaSauce"
		}
	}
}

Créer le secret dans Kubernetes:

    kubectl create secret generic regcred --from-file=.dockerconfigjson=/var/lib/jenkins/.docker/config.json --type=kubernetes.io/dockerconfigjson

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
 
 
