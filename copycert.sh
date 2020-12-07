CERTFILE=${1:-resources/cert/lacave-root-ca.crt}
PEMFILE=${2:-resources/cert/lacave-root.pem}
HOSTS="
kube01
kube02
kube03"

for HOST in $HOSTS; do
  scp $CERTFILE root@${HOST}:/etc/pki/ca-trust/source/anchors
  ssh root@${HOST} update-ca-trust
  ssh root@${HOST} mkdir -p /etc/kubernetes/ssl
  scp $PEMFILE root@${HOST}:/etc/kubernetes/ssl
done
