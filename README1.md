# Projet d'un cluster Kubernetes avec Kubeadm sur environnement Ubuntu/Linux

  # Conditions préalables
  - Une paire de clés SSH sur votre machine Linux / macOS / BSD locale.
  - Trois serveurs exécutant Ubuntu 18.04 ou latest avec 2 Go de RAM et 2 vCPU chacun en LABO-INSPQ
  - Ansible installé sur votre machine locale ( elle servira de Maitre pour les 2 autres clients )
  - Installation de docker pour le lancement d'un / plusieurs conteneur a partir des images 
  
  # Étape 1 - Configuration du répertoire de l'espace de travail et du fichier d'inventaire Ansible
  
   Créez un répertoire nommé ~ / kube-cluster dans le répertoire personnel de votre machine locale avec la commande suivante :
  
   Ce répertoire sera votre espace de travail pour le reste du deploiement et contiendra tous nos playbooks Ansible. 
   Ce sera également le répertoire dans lequel vous exécuterez toutes les commandes locales.
  
    $ mkdir ~/kube-cluster
    $ cd ~/kube-cluster
  
   Créez un fichier nommé ~ / kube-cluster / hosts en utilisant vim ou gedit : 
   
    $ vim ~/kube-cluster/hosts
  
   Ce fichier contiendra la strcuture logique de notre cluster.
  
 # Étape 2 - Création d'un utilisateur non root sur tous les serveurs distants ( permet de facilement faire des maintenances )
   
   Créez un fichier nommé ~ / kube-cluster / initial.yml dans l'espace de travail:
    
   Ensuite, exécutez le playbook en exécutant localement:
   
    $ ansible-playbook -i hosts ~/kube-cluster/initial.yml
   
 # Étape 3 - Installation des dépendances de Kubernetetes
   
   Installez les packages au niveau du système d'exploitation requis par Kubernetes avec le gestionnaire de packages d'Ubuntu. Ces packages sont:
   
   - Docker : un runtime de conteneur.
   - kubeadm : un outil CLI qui installera et configurera les différents composants d'un cluster de manière standard.
   - kubelet : a system service/program that runs on all nodes and handles node-level operations.
   - kubectl : un outil CLI utilisé pour émettre des commandes vers le cluster via son serveur API.
   
  Créez un fichier nommé ~ / kube-cluster / kube-dependencies.yml dans l'espace de travail:

    $ vi ~/kube-cluster/kube-dependencies.yml
  
  (NB: veuillez consultez les mises a jour pour les dependences)
       
   Ensuite, exécutez le playbook en exécutant localement:
   
    $ ansible-playbook -i hosts ~/kube-cluster/kube-dependencies.yml
    
 # Étape 4 - Configuration du nœud maître
  
 Créez un playbook Ansible nommé master.yml pour installer Flannel (Flanel est un réseau virtuel qui donne un sous-réseau à chaque hôte) sur votre machine locale:
  
    $ nano ~/kube-cluster/master.yml
      
   Ensuite, exécutez le playbook en exécutant localement:
      
    $ ansible-playbook -i hosts ~/kube-cluster/master.yml
      
   Pour vérifier l'état du nœud maître, connectez-y SSH avec la commande suivante:
      
    $ ssh ubuntu@master_ip
      
   Une fois à l'intérieur du nœud maître, exécutez:
      
    $ kubectl get nodes
    
   Vous devrez voir en sortie que la master est pret :
    
    Output
    NAME      STATUS    ROLES     AGE       VERSION
    master    Ready     master    1d        v1.14.0 ( version peut changer )
    
 # Étape 5 - Configuration des nœuds de travail
   
   # Initialisation des jetons securises permettant aux noeuds inscrits de rejoindre le cluster ( similaire au PKI dans le README de Phillipe )
    
   Revenez à votre espace de travail et créez un playbook nommé workers.yml:
    
    $ vim ~/kube-cluster/workers.yml
    
   Ensuite, exécutez le playbook en exécutant localement:
      
    $ ansible-playbook -i hosts ~/kube-cluster/workers.yml
    
 # Étape 6 - Vérification du cluster
    
    $ ssh ubuntu@master_ip
   
   Exécutez ensuite la commande suivante pour obtenir l'état du cluster
   
    $ kubectl get nodes
   
   Vous verrez une sortie similaire à la suivante:
   
    Output
  
    NAME      STATUS    ROLES     AGE       VERSION
    master    Ready     master    1d        v1.14.0
    worker1   Ready     <none>    1d        v1.14.0
    worker2   Ready     <none>    1d        v1.14.0
  
# Étape 7 - Exécution d'une application sur le cluster
  
  # Deploiement de nginx a l'aide de Deployment et Services
  
  Toujours dans le nœud maître, exécutez la commande suivante pour créer un déploiement nommé nginx:
    
    $ kubectl create deployment nginx --image=nginx
  
  Le déploiement ci-dessus créera un module contenant un conteneur à partir de l'image Nginx Docker du registre Docker.
  
  Ensuite, exécutez la commande suivante pour créer un service nommé nginx qui exposera l'application publiquement.
  Il le fera via un NodePort, un schéma qui rendra le pod accessible via un port arbitraire ouvert sur chaque nœud du cluster:
    
    $ kubectl expose deploy nginx --port 80 --target-port 80 --type NodePort
  
  Exécutez la commande suivante:
    
    $ kubectl get services
  
  Nous devrons avoir en sortie : 
    
    Output
    NAME         TYPE        CLUSTER-IP       EXTERNAL-IP           PORT(S)             AGE
    kubernetes   ClusterIP   ip_add       <none>                443/TCP             1d
    nginx        NodePort    ip-add-1   <none>                80:nginx_port/TCP   40m

# Pour tester que tout fonctionne, visitez http: // worker_1_ip: nginx_port ou http: // worker_2_ip: nginx_port via un navigateur sur votre machine locale


  
  
   

   
   
    
    
    
    
  
  
