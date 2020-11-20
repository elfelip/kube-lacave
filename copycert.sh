HOSTS="
kube01
kube02
kube03"

for HOST in $HOSTS; do
  scp resources/cert/lacave-root.pem root@${HOST}:/etc/pki/ca-trust/source/anchors
  ssh root@${HOST} update-ca-trust
  ssh root@${HOST} mkdir -p /etc/kubernetes/ssl
  scp resources/cert/lacave-root.pem root@${HOST}:/etc/kubernetes/ssl
done