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
  
   Ce fichier contiendra la strcuture logique de notre cluster. Ajouter les specifications suivantes,
  
   # Cette premiere ligne specifie des commandes distantes en tant qu'utilisateur root pour le Maitre et les clients
   [masters]
   master ansible_host=master_ip ansible_user=root

   [workers]
   worker1 ansible_host=worker_1_ip ansible_user=root
   worker2 ansible_host=worker_2_ip ansible_user=root
   
   # Indique à Ansible d'utiliser les interprètes Python 3 des serveurs distants pour ses opérations de gestion.
   [all:vars]
   ansible_python_interpreter=/usr/bin/python3
 
 # Étape 2 - Création d'un utilisateur non root sur tous les serveurs distants ( permet de facilement faire des maintenances )
   
   Créez un fichier nommé ~ / kube-cluster / initial.yml dans l'espace de travail:
    * Ajoutez la lecture suivante au fichier pour créer un utilisateur non root avec des privilèges sudo sur tous les serveurs, puis sauvegarder
   
   - hosts: all
  become: yes
  tasks:
    - name: create the 'ubuntu' user
      user: name=ubuntu append=yes state=present createhome=yes shell=/bin/bash

    - name: allow 'ubuntu' to have passwordless sudo
      lineinfile:
        dest: /etc/sudoers
        line: 'ubuntu ALL=(ALL) NOPASSWD: ALL'
        validate: 'visudo -cf %s'

    - name: set up authorized keys for the ubuntu user
      authorized_key: user=ubuntu key="{{item}}"
      with_file:
        - ~/.ssh/id_rsa.pub
   
   Ensuite, exécutez le playbook en exécutant localement:
   $ ansible-playbook -i hosts ~/kube-cluster/initial.yml
   
 # Étape 3 - Installation des dépendances de Kubernetetes
   
   Installez les packages au niveau du système d'exploitation requis par Kubernetes avec le gestionnaire de packages d'Ubuntu. Ces packages sont:
   
   - Docker : un runtime de conteneur.
   - kubeadm : un outil CLI qui installera et configurera les différents composants d'un cluster de manière standard.
   - kubelet : a system service/program that runs on all nodes and handles node-level operations.
   - kubectl : un outil CLI utilisé pour émettre des commandes vers le cluster via son serveur API.
   
  Créez un fichier nommé ~ / kube-cluster / kube-dependencies.yml dans l'espace de travail:
   $ vim ~/kube-cluster/kube-dependencies.yml
  
  Ajoutez les variables suivantes au fichier pour installer ces packages sur vos serveurs, puis sauvegardez.
  (NB: veuillez consultez les mises a jour pour les dependences)
  
  - hosts: all
  become: yes
  tasks:
   - name: install Docker
     apt:
       name: docker.io
       state: present
       update_cache: true

   - name: install APT Transport HTTPS
     apt:
       name: apt-transport-https
       state: present

   - name: add Kubernetes apt-key
     apt_key:
       url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
       state: present

   - name: add Kubernetes' APT repository
     apt_repository:
      repo: deb http://apt.kubernetes.io/ kubernetes-xenial main
      state: present
      filename: 'kubernetes'

   - name: install kubelet
     apt:
       name: kubelet=1.14.0-00
       state: present
       update_cache: true

   - name: install kubeadm
     apt:
       name: kubeadm=1.14.0-00
       state: present

- hosts: master
  become: yes
  tasks:
   - name: install kubectl
     apt:
       name: kubectl=1.14.0-00
       state: present
       force: yes
       
   Ensuite, exécutez le playbook en exécutant localement:
    $ ansible-playbook -i hosts ~/kube-cluster/kube-dependencies.yml
    
 # Étape 4 - Configuration du nœud maître
  
  Créez un playbook Ansible nommé master.yml sur votre machine locale:
    $ nano ~/kube-cluster/master.yml
    
    * Ajoutez la lecture suivante au fichier pour initialiser le cluster et installer # Flannel:
    
   - hosts: master
  become: yes
  tasks:
    - name: initialize the cluster
      shell: kubeadm init --pod-network-cidr=10.244.0.0/16 >> cluster_initialized.txt
      args:
        chdir: $HOME
        creates: cluster_initialized.txt

    - name: create .kube directory
      become: yes
      become_user: ubuntu
      file:
        path: $HOME/.kube
        state: directory
        mode: 0755

    - name: copy admin.conf to user's kube config
      copy:
        src: /etc/kubernetes/admin.conf
        dest: /home/ubuntu/.kube/config
        remote_src: yes
        owner: ubuntu

    - name: install Pod network
      become: yes
      become_user: ubuntu
      shell: kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml >> pod_network_setup.txt
      args:
        chdir: $HOME
        creates: pod_network_setup.txt
      
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
   
   # Initialisation des jetons securises permettant aux noeuds inscrits de rejoindre le cluster
    
    Revenez à votre espace de travail et créez un playbook nommé workers.yml:
      $ vim ~/kube-cluster/workers.yml
    
    * Ajoutez le texte suivant au fichier pour ajouter les travailleurs au clusterm puis sauvegarez
      
      - hosts: master
  become: yes
  gather_facts: false
  tasks:
    - name: get join command
      shell: kubeadm token create --print-join-command
      register: join_command_raw

    - name: set join command
      set_fact:
        join_command: "{{ join_command_raw.stdout_lines[0] }}"

- hosts: workers
  become: yes
  tasks:
    - name: join cluster
      shell: "{{ hostvars['master'].join_command }} >> node_joined.txt"
      args:
        chdir: $HOME
        creates: node_joined.txt
    
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


  
  
   

   
   
    
    
    
    
  
  
