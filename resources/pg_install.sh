#!/bin/bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo update
helm install pgtest stable/postgresql \
    --namespace test \
    --set global.postgresql.postgresqlDatabase=testdb \
    --set global.postgresql.postgresqlUsername=test \
    --set global.postgresql.postgresqlPassword=CeciEstUnTest \
    --set global.postgresql.servicePort=5432 \
    --set global.storageClass=local-path \
    --set replication.slaveReplicas=2 \
    --set replication.synchronousCommit=on \
    --set replication.numSynchronousReplicas=2

helm upgrade pgtest stable/postgresql \
    --namespace test \
    --set global.postgresql.postgresqlDatabase=testdb \
    --set global.postgresql.postgresqlUsername=test \
    --set global.postgresql.postgresqlPassword=CeciEstUnTest \
    --set global.postgresql.servicePort=5432 \
    --set global.storageClass=local-path \
    --set replication.slaveReplicas=2 \
    --set replication.synchronousCommit=on \
    --set replication.numSynchronousReplicas=2
