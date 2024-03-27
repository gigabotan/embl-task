# Log

> I was in the vacation at my hometown during last week and I had very unstable internet, so I implemented and tested everything first locally and then replicated on given infrastructure.
> Sorry, last part of the log little bit chaotic, because it took longer than I expected and I had no time to do it properly.


## Preparation
- **Read tasks carefully, check requirements and prepared infrastructure**
- First we have to check that everything is clear and we can start working on the task.
- Download task files
- Then check if all necessary files are available and we can connect to hosts via ssh.
  ```sh
  local$ eval $(ssh-agent -s)
  local$ ssh-add ./id_embl
  local$ ssh -A ubuntu@45.88.80.66
  # ssh from bastion to master and worker nodes
  bastion$ ssh ubuntu@192.168.13.106
  bastion$ ssh ubuntu@192.168.13.80
  ```

- Prepare convenient working enviroment locally
- create `ssh` config for the task
  ```sh
  # ./sshconfig
  Host *
    ForwardAgent yes
    ServerAliveInterval 300
    ServerAliveCountMax 2
    User ubuntu

  Host bastion
      HostName 45.88.80.66

  Host master
      HostName 192.168.13.106
      ProxyJump bastion

  Host worker
      HostName 192.168.13.80
      ProxyJump bastion
  ```
- check ssh connection to each host
  ```sh
  local$ ssh -F./sshconfig bastion
  local$ ssh -F./sshconfig master
  local$ ssh -F./sshconfig worker
  ```
- create git repo for the solution


## Plan and design architecture

Now lets talk about future architecture.

We have 3 tasks:
1. install rke2 1.27 
2. deploy wordpress
3. (BONUS) upgrade rke2 to 1.28

### 1. RKE2 installation design
Cluster installation is pretty straighforward:
- Google what is RKE2?
- Check [requirements](https://docs.rke2.io/install/requirements)
- Check [official installation documentation](https://docs.rke2.io/install/quickstart) 

>I assume this can take aroun 1-4 hours depending on unpredictable issues

Full installation process is described [later](#rke2-installation)

### 2. Wordpress
This is a little bit tricky, because there are multiple ways to deploy wordpress application.
We can deploy minimal single-instance solution or HA setup.
For minimal setup we can even use tutorial from [kubernetes docs](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/)

#### Minimal wordpress
Minimum installation should include:
 - wordpress
   - single wordpress deployment
   - single RWO storage (looks like this is the common way)
     - pv hostPath
     - pvc
 - mysql
   - single mariadb deployment
   - single RWO storage
     - pv hostPath
     - pvc
   - service
     - clusterIP: None
 - Optional:
   - wordpress service

#### HA setup
However, minimal setup will not be enough for HA setup and zero-downtime kubernetes upgrade, which is required for the next task.

For the HA setup, we will need:
- HA storage
  - I have researched different solutions and chosen Longhorn. It is pretty easy to deploy and use.
- HA Mysql database
  - Galera cluster should be ok. 
- HA wordpress
  - We can use replicated deployment with RWX storage backed by Longhorn.

### 3. Kubernetes upgrade
This task also looks not very hard. However we have to carefully plan each step of the upgrade process.
Detailed upgrade steps are described [later](#kubernetes-upgrade)


## **Start actual work**

## RKE2 installation
> Following official docs https://docs.rke2.io/install/quickstart

I have decided to not use [taint to server nodes](https://docs.rke2.io/install/ha/#2a-optional-consider-server-node-taints), because we will need to run our pods on `mater` node during `worker` upgrade.


1. Server
```sh
master$ curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.27.10+rke2r1 sh - 
# Optional: 
master$ sudo systemctl enable rke2-server.service
master$ sudo systemctl start rke2-server.service
master$ sudo systemctl status rke2-server.service
# Check logs
worker$ journalctl -u rke2-server -f
# Get kubeconfig
master$ sudo cat /etc/rancher/rke2/rke2.yaml
# Get token for the agent
master$ sudo cat /var/lib/rancher/rke2/server/node-token
```
2. Worker
```sh
worker$ curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.27.10+rke2r1 INSTALL_RKE2_TYPE=agent  sh -
worker$ sudo systemctl enable rke2-agent.service
worker$ sudo mkdir -p /etc/rancher/rke2/
# Add token and server address
worker$ sudo vim /etc/rancher/rke2/config.yaml
worker$ sudo systemctl start rke2-agent.service
worker$ journalctl -u rke2-agent -f
```
3. Locally 
```sh
$ vim ./kubeconfig
$ export KUBECONFIG=${PWD}/kubeconfig
# Port forward via ssh to access kube api from local machine
$ ssh -F ./sshconfig -L 6443:localhost:6443 master
#Check cluster access and nodes
$ kubectl get nodes
NAME       STATUS   ROLES                       AGE     VERSION
master-4   Ready    control-plane,etcd,master   32m     v1.27.10+rke2r1
worker-4   Ready    <none>                      3m28s   v1.27.10+rke2r1
```

## Longhorn installation

1. Check longhorn requirements from master node
```sh
master$ sudo cp /etc/rancher/rke2/rke2.yaml ./
master$ sudo chown ubuntu:ubuntu ./rke2.yaml
master$ sudo chmod 777 /var/lib/rancher/rke2/bin/*
master$ export PATH=$PATH:/var/lib/rancher/rke2/bin/
master$ export KUBECONFIG=${PWD}/rke2.yaml
master$ curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/scripts/environment_check.sh | bash
# Install requirements for both node
master$ sudo apt install -y jq nfs-common
master$ curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/scripts/environment_check.sh | bash
[INFO]  Required dependencies 'kubectl jq mktemp sort printf' are installed.
[INFO]  All nodes have unique hostnames.
[INFO]  Waiting for longhorn-environment-check pods to become ready (0/2)...
[INFO]  All longhorn-environment-check pods are ready (2/2).
[INFO]  MountPropagation is enabled
[INFO]  Checking kernel release...
[INFO]  Checking iscsid...
[INFO]  Checking multipathd...
[WARN]  multipathd is running on master-4
[WARN]  multipathd is running on worker-4
[INFO]  Checking packages...
[INFO]  Checking nfs client...
[INFO]  Cleaning up longhorn-environment-check pods...
[INFO]  Cleanup completed.


local$ helm pull longhorn/longhorn --version 1.6.0 --untar 
local$ cp longhorn/values.yaml ./longhorn-values.yaml
local$ vim ./longhorn-values.yaml
local$ helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version 1.6.0 --values ./longhorn-values.yaml
# Port-forward to check via UI
local$ kubectl port-forward -n longhorn-system services/longhorn-frontend 8090:80
```
Now we can check if Longhorn is working properly.
Create storage for the wordpress
```
# ./wordpress-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress
  namespace: wordpress
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 20Gi
```

```
$ kubectl apply -f ./wordpress-pvc.yaml
$ kubectl get pvc -o wide -n wordpress
NAMESPACE   NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE    VOLUMEMODE
wordpress   wordpress   Bound    pvc-03ef8406-33a1-4283-a71d-7fe68cf15a80   20Gi       RWX            longhorn       6m1s   Filesystem
```

## Galera installation (HA MariaDB cluster)
```sh
local$ helm pull oci://registry-1.docker.io/bitnamicharts/mariadb-galera --version 12.0.0 --untar
local$ cp mariadb-galera/values.yaml ./galera-values.yaml
local$ kubectl apply -f secret-galera.yml
local$ helm install galera oci://registry-1.docker.io/bitnamicharts/mariadb-galera --version 12.0.0 --namespace galera --values ./galera-values.yaml
local$ Check connection

$ kubectl run galera-mariadb-galera-client --rm --tty -i --restart='Never' --namespace galera --image docker.io/bitnami/mariadb-galera:11.2.3-debian-12-r4 --command \
      -- mysql -h galera-mariadb-galera -P 3306 -uwordpress -p$(kubectl get secret --namespace galera galera-secret -o jsonpath="{.data.mariadb-password}" | base64 -d) wordpress

If you don't see a command prompt, try pressing enter.
MariaDB [wordpress]> \s
--------------
mysql from 11.2.3-MariaDB, client 15.2 for Linux (x86_64) using readline 5.1

Connection id:          40
Current database:       wordpress
Current user:           wordpress@10.42.1.19
SSL:                    Not in use
Current pager:          stdout
Using outfile:          ''
Using delimiter:        ;
Server:                 MariaDB
Server version:         11.2.3-MariaDB-log Source distribution
Protocol version:       10
Connection:             galera-mariadb-galera via TCP/IP
Server characterset:    utf8mb3
Db     characterset:    utf8mb3
Client characterset:    utf8mb3
Conn.  characterset:    utf8mb3
TCP port:               3306
Uptime:                 3 min 33 sec

Threads: 7  Questions: 51  Slow queries: 9  Opens: 22  Open tables: 13  Queries per second avg: 0.239
--------------

MariaDB [wordpress]>
```


## Wordpress installation
Plan is:
1. Install using [popular helm chart](https://github.com/bitnami/charts/tree/main/bitnami/wordpress)
   1. 1 replica during first install
2. Redeploy with 2 replicas and skip installation
3. Redeploy with ingress and skip installation


```sh
# Create secrets
$ kubectl apply -f secret-wp.yml
$ helm pull oci://registry-1.docker.io/bitnamicharts/wordpress --version 21.0.6 --untar
#
$ helm install wordpress oci://registry-1.docker.io/bitnamicharts/wordpress --version 21.0.6 --namespace wordpress --values ./wordpress-values.yaml
# Check pods
$ kubectl get pods -w
# Something wrong, check logs
$ kubectl logs -f wordpress-wordpress-659956946f-42674 -n wordpress
# Not enought logs, deploy new version with DEBUG flag
## edit ./wordpress-values.yaml
## image.debug: false
$ helm upgrade wordpress oci://registry-1.docker.io/bitnamicharts/wordpress --version 21.0.6 --namespace wordpress --values ./wordpress-values.yaml
# Troubleshooting
## Check user ID in database
$ kubectl run galera-mariadb-galera-client --rm --tty -i --restart='Never' --namespace galera --image docker.io/bitnami/mariadb-galera:11.2.3-debian-12-r4 --command \\n      -- mysql -h galera-mariadb-galera -P 3306 -uwordpress -p$(kubectl get secret --namespace galera galera-secret -o jsonpath="{.data.mariadb-password}" | base64 -d) wordpress\
mysql> SELECT * FROM wp_users; 
# quick googling for more info
# https://github.com/bitnami/charts/issues/7535
# https://github.com/bitnami/charts/issues/12020
# https://mariadb.org/auto-increments-in-galera/
# Quick fix
## Ccreate user with ID=1 from user with ID=2
mysql> INSERT INTO wp_users(ID,user_login,user_pass,user_nicename,user_email,user_url,user_registered,user_activation_key,user_status,display_name) VALUES(1,'user','$P$BD0diyRdVulvdIPOYXBL60HLP8VSd60','user','user@example.com','http://127.0.0.1','2024-03-27 12:32:31','',0,'user');
mysql> DELETE FROM wp_users WHERE ID=2;
# Sorry for bad SQL :D
# Check pods again
8. Redeploy with 2 replicas and skip installation step
# edit ./wordpress-values.yaml
# image.debug: true
# replicaCount: 2
# wordpressSkipInstall: true
$ helm upgrade wordpress oci://registry-1.docker.io/bitnamicharts/wordpress --version 21.0.6 --namespace wordpress --values ./wordpress-values.yaml
# Check new pods are running and ensure old version is downscaled to 0
# Check web UI
$ kubectl port-forward svc/wordpress 8080:80 -n wordpress
# open browser on http://localhost:8080/

## Prepare for kubernetes upgrade

1. Setup ingress for wordpress
   1. edit wordpress-values.yaml, enable ingress
   2. check ingress is deployed
      ```sh
      $ kubectl get ingress -o wide -n wordpress
      NAME        CLASS    HOSTS                ADDRESS                        PORTS   AGE
      wordpress   <none>   embl.gigabotan.com   192.168.13.106,192.168.13.80   80      21m
      ```
   3. check ingress is working from bastion node
      ```sh
      $ curl -I -H "Host: embl.gigabotan.com" 192.168.13.106
      HTTP/1.1 200 OK
      Date: Wed, 27 Mar 2024 14:07:57 GMT
      Content-Type: text/html; charset=UTF-8
      Connection: keep-alive
      Link: <http://embl.gigabotan.com/wp-json/>; rel="https://api.w.org/"
      ```
2. Prepare external LB
   1. I assume we can use `bastion` node as external LB for testing purposes
   2. Set up local dns (I use pihole on my home router)
      1. A record for `embl.gigabotan.com` points to bastion node
   3. Install docker on bastion
   4. We will use caddy as LB
      1. Create caddyfile





## Kubernetes upgrade

Important docs:
- https://longhorn.io/docs/1.6.0/maintenance/maintenance/#upgrading-kubernetes
- https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/


0. Ensure HA 
   1. HA setup of the wordpress and database
   2. Longhorn
   3. DNS with 2 A records or external LB
1. Upgrade master
   1. Drain node
   2. ```
      $ kubectl get nodes
      NAME       STATUS                     ROLES                       AGE   VERSION
      master-4   Ready,SchedulingDisabled   control-plane,etcd,master   14h   v1.27.10+rke2r1
      worker-4   Ready                      <none>                      13h   v1.27.10+rke2r1
      $ kubectl drain --ignore-daemonsets master-4 --delete-emptydir-data --grace-period=-1 --timeout=120s
      $ kubectl get nodes

   3. Wait for pods to be terminated
   4. Wait for pods to be recreated on worker node
   5. Upgrade rke2
   ```sh
   $ curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.28.8+rke2r1 sh -
   $ sudo systemctl restart rke2-server.service
   ```
      > Check if wordpress available during update
   8. Uncordon node
   9.  Wait for pods to be recreated on master node
       1.  Actually I skipped this step because of time constraints, sorry
       2.  We can achieve graceful migration during next drain by using PodDisruptionBudgets
2. Upgrade worker
   1. Drain node
   2. Wait for pods to be terminated
   3. Wait for pods to be recreated on master node
   4. Upgrade rke2
   5. Uncordon node
   6. Wait for pods to be recreated on worker node


# Known issues

- Admin page is broken, possibly because error during installation and quick hack fix with moving user ID to 1
  - Next time we should deploy only 1 replica of galera and 1 replica of wordpress during installation, and then rescale gradually to 2 replicas of each
- Broken http links in wordpress:
  - Problem: 
    - tls is handled by caddy and not by wordpress ingress
    - wordpress generated links as `http://smth`
    - Error in browser:
      > Mixed Content: The page at 'https://embl.gigabotan.com/' was loaded over HTTPS, but requested an insecure stylesheet 'http://embl.gigabotan.com/wp-includes/blocks/navigation/style.min.css?ver=6.4.3'. This request has been blocked; the content must be served over HTTPS.
  - Need to enable tls for wordpress ingress