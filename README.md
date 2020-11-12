# List all OpenShift certificate 
- Usage
```bash
./check-all-certificates.sh
```
Sample output
```bash
===============================================
Project: openshift-sdn
Secret: sdn-metrics-certs
Created at: 12-11-2020 00:00:00
Expired after: 10-11-2022 13:15:21
Day remaining 727
===============================================
Project: openshift-service-ca
Secret: signing-key
Created at: 12-11-2020 00:00:00
Expired after: 08-01-2023 21:36:49
Day remaining 787
===============================================
```
- For CSV format
```bash
./check-all-certificates.sh csv
```
Sample output
```csv
PROJECT,SECRET,CREATED_DATE,EXPIRED_DATE,DAY_REMAIN
openshift-sdn,sdn-metrics-certs,12-11-2020 00:00:00,10-11-2022 13:15:21,727
openshift-service-ca,signing-key,12-11-2020 00:00:00,08-01-2023 21:36:49,787
```
