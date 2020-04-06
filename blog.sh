#!/bin/bash

GCLOUD=$(which gcloud)
KUBECTL=$(which kubectl)
if [ ! -f "$GCLOUD" ]; then 
    echo "Google Cloud SDK is not installed. Install it first: https://cloud.google.com/sdk/install"
    exit 1
fi

if [ ! -f "$KUBECTL" ]; then 
    echo "kubectl is not installed. Install it first: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi
# TODO: check kubectl

# var
REGION="asia-southeast1"
ZONE="asia-southeast1-a"

K8S_NODE_TIER="n1-standard-1"
DB_NODE_TIER="db-n1-standard-1"

NAME="wp-shopee"
K8S_CLUSTER_NAME="k8s-$NAME"
DB_CLUSTER_NAME="abcde-$NAME"
DB_NAME="db-$NAME"
DB_USER=$NAME

WORKING_DIR=$(pwd)

# run app by argument
args=("$@")

login_gcp () {
    ACTIVE_ACCOUNT=$($GCLOUD auth list --filter=status:ACTIVE --format="value(account)")
    if [ -z $ACTIVE_ACCOUNT ]; then
        echo "init account"
        $GCLOUD init
    fi

    PROJECT_ID=$($GCLOUD config get-value project 2> /dev/null)

    $GCLOUD config set compute/region $REGION
    $GCLOUD config set compute/zone $ZONE
}

init () {
    # create kubernetes cluster
    $GCLOUD container clusters create $K8S_CLUSTER_NAME --machine-type=$K8S_NODE_TIER --num-nodes=1 --zone=$ZONE

    # get k8s credentials
    $GCLOUD container clusters get-credentials $K8S_CLUSTER_NAME

    # create cloudsql cluster
    $GCLOUD sql instances create $DB_CLUSTER_NAME --tier=$DB_NODE_TIER --zone=$ZONE

    export INSTANCE_CONNECTION_NAME=$($GCLOUD sql instances describe $DB_CLUSTER_NAME \
        --format='value(connectionName)')

    # create database user and password
    export DB_PASSWORD=$(openssl rand -base64 18)
    $GCLOUD sql users create $DB_USER --host=% --instance $DB_CLUSTER_NAME \
        --password $DB_PASSWORD

    # create service account for database access inside wordpress k8s pod
    SA_NAME="$NAME-cloudsql-proxy"
    $GCLOUD iam service-accounts create $SA_NAME --display-name $SA_NAME

    SA_EMAIL=$($GCLOUD iam service-accounts list \
        --filter=displayName:$SA_NAME \
        --format='value(email)')
    
    $GCLOUD iam service-accounts keys create $WORKING_DIR/k8s/key.json \
        --iam-account $SA_EMAIL

    # create secret for wordpress
    $KUBECTL create secret generic cloudsql-db-credentials \
        --from-literal username=$DB_USER \
        --from-literal password=$DB_PASSWORD

    $KUBECTL create secret generic cloudsql-instance-credentials \
        --from-file $WORKING_DIR/k8s/key.json

    # fill template file with env var value
    cat $WORKING_DIR/k8s/deployment.yaml.template | envsubst > \
        $WORKING_DIR/k8s/deployment.yaml
    
    # deploy wordpress
    $KUBECTL apply -f $WORKING_DIR/k8s/pv-claim.yaml
    $KUBECTL apply -f $WORKING_DIR/k8s/deployment.yaml
    $KUBECTL apply -f $WORKING_DIR/k8s/service.yaml
    $KUBECTL apply -f $WORKING_DIR/k8s/ingress.yaml

    # get loadbalancer IP address
    IP_ADDRESS=$($KUBECTL get ingress -o=jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
    echo "Finish! Your wordpress IP address is accessable at http://$IP_ADDRESS"
}


resize () {
    echo "scaling deployment to ${args[1]}"
    $KUBECTL scale deployment/wordpress --replicas=${args[1]}
}

case ${args[0]} in 
    login)
        login_gcp
        ;;
    init)
        init
        ;;
    resize)
        resize
        ;;
    *)
        echo "Usage: ./blog.sh login | init | resize [num_resize]"
        ;;
esac
