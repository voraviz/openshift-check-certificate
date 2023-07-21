#!/bin/bash
test_login(){
    oc whoami 1>/dev/null 2>&1
    if [ $? -ne 0 ];
    then
        printf "You need to login with \"oc login\" before run this script"
        exit 1
    fi
}
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
calculate(){
    END_EPOCH=$($DATE --date="${NOT_AFTER}" +"%s")
    START_EPOCH=$($DATE --date="${NOT_BEFORE}" +"%s")
    END_DATE=$($DATE  -d @$END_EPOCH +'%d-%m-%Y %H:%M')
    START_DATE=$($DATE  -d @$START_EPOCH +'%d-%m-%Y %H:%M')
    DIFF=$(expr $END_EPOCH - $NOW_EPOCH)
    CERT_VALID_FOR=$(expr $END_EPOCH - $START_EPOCH)
    DAY_REMAIN=$(expr $DIFF / 86400)
    DAY_VALID=$(expr $CERT_VALID_FOR / 86400)
}
print_output(){
     if [ $OUTPUT = "csv" ];
        then
            printf "$DESC,$START_DATE,$END_DATE,$DAY_VALID,$DAY_REMAIN\n"
        else
            printf "%s\n" "==============================================="
            printf "Description: $DESC\n" 
            printf "Created at: %s %s\n" $START_DATE
            printf "Expired after: %s %s\n" $END_DATE
            printf "Certificate valid for %s days\n" $DAY_VALID
            printf "Day remaining %s \n" $DAY_REMAIN
        fi
}
check(){
    DESC=$1
    PROJECT=$2
    SECRET=$3
    if [ $# -eq 4 ];
    then
        ATTRIBUTE="$4"
    else
        ATTRIBUTE=":.data.tls\.crt"
    fi

    oc get secret -n $PROJECT $SECRET \
    -o yaml -o=custom-columns="$ATTRIBUTE" \
    | tail -1 | base64 -d | openssl x509 -noout -enddate 1>/dev/null 2>&1

    if [ $? -eq 0 ];
    then
        NOW_EPOCH=$($DATE +"%s")
        NOT_AFTER=$(oc get secret -n $PROJECT $SECRET \
        -o yaml -o=custom-columns="$ATTRIBUTE" \
        | tail -1 | base64 -d | openssl x509 -noout -enddate|awk -F'notAfter=' '{print $2}')    
        NOT_BEFORE=$(oc get secret -n $PROJECT $SECRET \
        -o yaml -o=custom-columns="$ATTRIBUTE" \
        | tail -1 | base64 -d | openssl x509 -noout -startdate|awk -F'notBefore=' '{print $2}')
        calculate
        # END_EPOCH=$($DATE --date="${NOT_AFTER}" +"%s")
        # START_EPOCH=$($DATE --date="${NOT_BEFORE}" +"%s")
        # END_DATE=$($DATE  -d @$END_EPOCH +'%d-%m-%Y %H:%M')
        # START_DATE=$($DATE  -d @$START_EPOCH +'%d-%m-%Y %H:%M')
        # DIFF=$(expr $END_EPOCH - $NOW_EPOCH)
        # CERT_VALID_FOR=$(expr $END_EPOCH - $START_EPOCH)
        # DAY_REMAIN=$(expr $DIFF / 86400)
        # DAY_VALID=$(expr $CERT_VALID_FOR / 86400)
        print_output
        # if [ $OUTPUT = "csv" ];
        # then
        #     printf "$DESC,$START_DATE,$END_DATE,$DAY_VALID,$DAY_REMAIN\n"
        # else
        #     printf "%s\n" "==============================================="
        #     printf "Description: $DESC\n" 
        #     printf "Created at: %s %s\n" $START_DATE
        #     printf "Expired after: %s %s\n" $END_DATE
        #     printf "Certificate valid for %s days\n" $DAY_VALID
        #     printf "Day remaining %s \n" $DAY_REMAIN
        # fi
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
            check "Ingress <$secret>" openshift-ingress $secret
         fi
    done
}
check_monitoring(){
    for secret in $(oc get secrets -n openshift-monitoring | egrep " kubernetes.io/tls" |awk '{print $1}')
    do
         check "Monitoring <$secret>" openshift-monitoring $secret
    done
    check "Monitoring <kube-etcd-client-certs CA>" openshift-monitoring kube-etcd-client-certs ":.data.etcd-client-ca\.crt"
    check "Monitoring <kube-etcd-client-certs Client Cert>" openshift-monitoring kube-etcd-client-certs ":.data.etcd-client\.crt"
    check "Monitoring <prometheus-k8s-grpc-tls> Server CA" openshift-monitoring \
    $(oc get secret -n openshift-monitoring | grep prometheus-k8s-grpc | awk '{print $1}') \
    ":.data.server\.crt"
    check "Monitoring <prometheus-k8s-grpc-tls> CA" openshift-monitoring \
    $(oc get secret -n openshift-monitoring | grep prometheus-k8s-grpc | awk '{print $1}') \
    ":.data.ca\.crt"
    check "Monitoring <thanos-querier-grpc-tls> CA" openshift-monitoring \
    $(oc get secret -n openshift-monitoring | grep thanos-querier-grpc-tls | awk '{print $1}') \
    ":.data.ca\.crt"
    check "Monitoring <thanos-querier-grpc-tls> Client Cert" openshift-monitoring \
    $(oc get secret -n openshift-monitoring | grep thanos-querier-grpc-tls | awk '{print $1}') \
    ":.data.client\.crt"
    check "Monitoring <grpc-tls CA>" openshift-monitoring grpc-tls ":.data.ca\.crt"
    check "Monitoring <grpc-tls Prometheus Server>" openshift-monitoring grpc-tls ":.data.prometheus-server\.crt"
    check "Monitoring <grpc-tls Querier-Client>" openshift-monitoring grpc-tls ":.data.thanos-querier-client\.crt"

    #check "Monitoring <grpc-tls>" openshift-monitoring grpc-tls
}
check_nodes(){
    kubelet=("kubelet-server-current.pem" "kubelet-client-current.pem" )
    for node in $(oc get nodes --no-headers -o custom-columns='Name:.metadata.name')
    do
       for cert in "${kubelet[@]}"
       do
         DESC="$node ($cert)"
         NOW_EPOCH=$($DATE +"%s")
         NOT_BEFORE=$(oc debug node/$node -- chroot /host cat /var/lib/kubelet/pki/$cert 1>/dev/null 2>&1| openssl x509  -noout -startdate|awk -F'notBefore=' '{print $2}')
         NOT_AFTER=$(oc debug node/$node -- chroot /host cat /var/lib/kubelet/pki/$cert 1>/dev/null 2>&1 | openssl x509  -noout -enddate|awk -F'notAfter=' '{print $2}')
        calculate
        print_output
       done
   done
}
test_login
set_date_cli
if [ $# -gt 0 ];
then
    if [ $1 = "csv" ];
    then
        OUTPUT="csv"
    fi
else
    OUTPUT="human"
fi
check "External API" openshift-kube-apiserver external-loadbalancer-serving-certkey 
check "Internal API" openshift-kube-apiserver internal-loadbalancer-serving-certkey 
check "Kube Controller Manager" openshift-kube-controller-manager kube-controller-manager-client-cert-key
check "Kube Scheduler" openshift-kube-scheduler kube-scheduler-client-cert-key 
check_etcd
check "Service-signer certificates" openshift-service-ca  signing-key
check_ingress
check_monitoring
check_nodes

# Pending check additional Monitoring / Logs


