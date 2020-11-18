#!/bin/bash
keytool -noprompt -importcert -trustcacerts -storepass changeit -file /certificats/lacave-root.pem -alias root_lacaveinfo
/usr/lib/jvm/java-11-openjdk/bin/keytool -noprompt -importcert -cacerts -storepass changeit -file /certificats/lacave-root.pem -alias root_lacaveinfo
cp /certificats/* /etc/pki/ca-trust/source/anchors
update-ca-trust extract
rm -rf /tmp/certificats
