#!/bin/bash
set_date_cli(){
    OS=$(uname)
    if [ $OS = "Darwin" ];
    then    
        which gdate 1>/dev/null 2>&1
        if [ $? -ne 0 ];
        then
            printf "POSIX date is not found. Please install POSIX date\n"
            printf "You can use brew install gdate to install POSIX date\n"
            exit 1
        else
            DATE=gdate
        fi
    else
        DATE=date
    fi
}
check(){
    DESC=$1
    PROJECT=$2
    SECRET=$3
    NOW_EPOCH=$($DATE +"%s")
    NOT_AFTER=$(oc get secret -n $PROJECT $SECRET \
    -o yaml -o=custom-columns=":.data.tls\.crt" \
    | tail -1 | base64 -d | openssl x509 -noout -enddate|awk -F'notAfter=' '{print $2}')
    NOT_BEFORE=$(oc get secret -n $PROJECT $SECRET \
    -o yaml -o=custom-columns=":.data.tls\.crt" \
    | tail -1 | base64 -d | openssl x509 -noout -enddate|awk -F'notBefore=' '{print $2}')
    END_EPOCH=$($DATE --date="${NOT_AFTER}" +"%s")
    START_EPOCH=$($DATE --date="${NOT_BEFORE}" +"%s")
    END_DATE=$($DATE  -d @$END_EPOCH +'%d-%m-%Y %H:%M')
    START_DATE=$($DATE  -d @$START_EPOCH +'%d-%m-%Y %H:%M')
    DIFF=$(expr $END_EPOCH - $NOW_EPOCH)
    DAY_REMAIN=$(expr $DIFF / 86400)
    if [ $OUTPUT = "csv" ];
    then
         printf "$DESC,$START_DATE,$END_DATE,$DAY_REMAIN\n"
    else
        printf "%s\n" "==============================================="
        printf "Description: $DESC\n" 
        printf "Created at: %s %s\n" $START_DATE
        printf "Expired after: %s %s\n" $END_DATE
        printf "Day remaining %s \n" $DAY_REMAIN
    fi
    
}
check_etcd(){
    etcd_certs=("etcd-peer" "etcd-serving" "etcd-serving-metrics")
    for master in $(oc get node -l node-role.kubernetes.io/master="" -o 'custom-columns=Name:.metadata.name' --no-headers)
    do
        for cert in "${etcd_certs[@]}"
        do
            type=$(echo $cert|sed 's/etcd-//')
            check "ETCD cert $type on $master" "openshift-etcd" $cert-$master
        done
    done
}
check_ingress(){
    for secret in $(oc get secret -n openshift-ingress --no-headers -o=custom-columns=":.metadata.name")
    do
         check=$(oc get secret $secret -n openshift-ingress -o jsonpath='{.data.tls\.crt}'|wc -c)
         if [ $check -gt 1 ];
         then
            check "Ingress $secret" openshift-ingress $secret
         fi
    done
}
if [ $# -gt 0 ];
then
    if [ $1 = "csv" ];
    then
        OUTPUT="csv"
    fi
else
    OUTPUT="human"
fi
set_date_cli
check "External API" openshift-kube-apiserver external-loadbalancer-serving-certkey 
check "Internal API" openshift-kube-apiserver internal-loadbalancer-serving-certkey 
check "Kube Controller Manager" openshift-kube-controller-manager kube-controller-manager-client-cert-key
check "Kube Scheduler" openshift-kube-scheduler kube-scheduler-client-cert-key 
check_etcd
# Pending check Nodes
check "Service-signer certificates" openshift-service-ca  signing-key
check_ingress
# Pending check Monitor / Logs


