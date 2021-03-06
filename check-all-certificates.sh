#!/bin/bash
#oc get secret --all-namespaces|grep -i "kubernetes.io/tls"|awk '{print "echo \"\n========== certificate "$2" in "$1" namespace ==========\n \";""oc get secret "$2" -n "$1" -o json| jq -r .data[\\\"tls.crt\\\"]| base64 -d | openssl x509 -in /dev/stdin -text -noout|egrep -i \"Subject:|Issuer:|Validity|Not\""}' > check_certificate.sh
OS=$(uname)
output(){
    if [ $# -gt 0 ];
        then
            if [ $1 == "csv" ];
            then
                printf "%s\n" "$PROJECT,$SECRET,$CERT,$($DATE -d @$START_EPOCH +'%d-%m-%Y %H:%M:%S'),$($DATE -d @$END_EPOCH +'%d-%m-%Y %H:%M:%S'),$DAY_REMAIN"
            fi
        else
            printf "%s\n" "==============================================="
            printf "Project: %s\n" $PROJECT
            printf "Secret: %s\n" $SECRET
            printf "Certificate File: %s\n" $CERT
            printf "Created at: %s\n" "$($DATE -d @$START_EPOCH +'%d-%m-%Y %H:%M:%S')"
            printf "Expired after: %s\n" "$($DATE -d @$END_EPOCH +'%d-%m-%Y %H:%M:%S')"
            printf "Day remaining %s \n" $DAY_REMAIN
        fi
}
check(){
    if [[ $SECRET =~ ^$1 ]];
        then
            NOT_ACTIVE=0
            if [ $ELAPSED_DAY -lt $2 ];
            then
               PRINT=0
            fi
        fi
}
if [ $OS == "Darwin" ];
then
    which gdate 1>/dev/null 2>&1
    if [ $? -ne 0 ];
    then
        echo "POSIX date is not found. Please install POSIX date"
        exit 1
    else
        DATE=gdate
    fi
else
    DATE=date
fi
NOW_EPOCH=$($DATE +"%s")
if [ $# -gt 0 ];
then
     if [ $1 == "csv" ];
        then
                printf "%s\n" "PROJECT,SECRET,CERT_FILE,CREATED_DATE,EXPIRED_DATE,DAY_REMAIN"
        fi
fi
for PROJECT in $(oc get projects --no-headers|grep 'openshift-'|awk '{print $1}')
do
    for SECRET in $(oc get secret -n $PROJECT --no-headers|awk '{print $1}'|sort)
    do
        for CERT in $(oc get secrets/$SECRET -n $PROJECT -o yaml | grep crt | grep -v "f:"|awk -F":" '{print $1}')
        do
            END_DATE=$(oc get secrets/$SECRET -n $PROJECT \
            -o template='{{index .data "'$CERT'"}}' \
            | base64 -d \
            | openssl x509 -noout -enddate|awk -F'notAfter=' '{print $2}')
             START_DATE=$(oc get secrets/$SECRET -n $PROJECT \
            -o template='{{index .data "'$CERT'"}}' \
            | base64 -d \
            | openssl x509 -noout -startdate|awk -F'notBefore=' '{print $2}')

            END_EPOCH=$($DATE --date="${END_DATE}" +"%s")
            START_EPOCH=$($DATE --date="${START_DATE}" +"%s")
            DIFF=$(expr $END_EPOCH - $NOW_EPOCH)
            DAY_REMAIN=$(expr $DIFF / 86400)
            CREATE_DATE=$(oc get secret/$SECRET -n $PROJECT -o jsonpath='{.metadata.creationTimestamp}')
            CREATE_EPOCH=$($DATE --date="${CREATE_DATE}" +"%s")
            ELAPSED=$(expr $NOW_EPOCH - $CREATE_EPOCH)
            ELAPSED_DAY=$(expr $ELAPSED / 86400)
            PRINT=1
            NOT_ACTIVE=1
            # check for cert with 30 days automatically rotate
            check kube-scheduler-client-cert-key 30
            check kubelet-client 30
            check kube-controller-manager-client-cert-key 30
             # OpenShift 4.5 does not contain this cert
            check kube-apiserver-cert-syncer-client-cert-key 30
            if [ $NOT_ACTIVE -eq 0 ];
            then
                if [ $PRINT -eq 0 ];
                then
                    output $1
                fi
            else
                output $1
            fi
        done
    done
done