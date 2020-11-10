#!/bin/bash
#oc get secret --all-namespaces|grep -i "kubernetes.io/tls"|awk '{print "echo \"\n========== certificate "$2" in "$1" namespace ==========\n \";""oc get secret "$2" -n "$1" -o json| jq -r .data[\\\"tls.crt\\\"]| base64 -d | openssl x509 -in /dev/stdin -text -noout|egrep -i \"Subject:|Issuer:|Validity|Not\""}' > check_certificate.sh
OS=$(uname)
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
echo $NOW
for PROJECT in $(oc get projects --no-headers|grep 'openshift-'|awk '{print $1}')
do
    for SECRET in $(oc get secret -n $PROJECT|grep -i 'kubernetes.io/tls'|awk '{print $1}'|sort -r)
    do
        END_DATE=$(oc get secrets/$SECRET -n $PROJECT \
        -o template='{{index .data "tls.crt"}}' \
        | base64 -d \
        | openssl x509 -noout -enddate|awk -F'notAfter=' '{print $2}')
        END_EPOCH=$($DATE --date="${END_DATE}" +"%s")
        DIFF=$(expr $END_EPOCH - $NOW_EPOCH)
        DAY_REMAIN=$(expr $DIFF / 86400)
        printf "%s\n" "==============================================="
        printf "Project: %s\n" $PROJECT
        printf "Secret: %s\n" $SECRET
        printf "Expired after: %s\n" "$($DATE -d @$END_EPOCH)"
        printf "Day remaining %s \n" $DAY_REMAIN
    done
done