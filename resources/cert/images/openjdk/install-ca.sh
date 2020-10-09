#!/bin/bash
keytool -noprompt -importcert $CACERTS -storepass changeit -file /tmp/certificats/lacave-root.pem -alias root_lacaveinfo
cp /tmp/certificats/* /etc/pki/ca-trust/source/anchors
update-ca-trust extract
rm -rf /tmp/certificats
