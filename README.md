# List all OpenShift certificate 
- Usage
```bash
./check-all-certificates.sh
```
Sample output
```bash
===============================================
Project: openshift-service-ca
Secret: signing-key
Created at: 09-11-2020 21:36:48
Expired after: 08-01-2023 21:36:49
Day remaining 786
===============================================
Project: openshift-service-ca-operator
Secret: serving-cert
Created at: 09-11-2020 21:37:12
Expired after: 09-11-2022 21:37:13
Day remaining 726
===============================================
```
- For CSV format
```bash
./check-all-certificates.sh csv
```
Sample output
```csv
PROJECT,SECRET,CREATED_DATE,EXPIRED_DATE,DAY_REMAIN
openshift-service-ca,signing-key,09-11-2020 21:36:48,08-01-2023 21:36:49,786
openshift-service-ca-operator,serving-cert,09-11-2020 21:37:12,09-11-2022 21:37:13,726
```
