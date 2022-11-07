# List all OpenShift certificate 
- Usage

    ```bash
    ./check-certificates.sh
    ```
    
    Sample output
    
    ```bash
    ===============================================
    Description: External API
    Created at: 07-11-2022 00:00
    Expired after: 07-12-2022 08:25
    Day remaining 29
    ===============================================
    Description: Internal API
    Created at: 07-11-2022 00:00
    Expired after: 07-12-2022 08:25
    Day remaining 29
    ===============================================
    ```

- For CSV format
    
    ```bash
    ./check-certificates.sh csv
    ```
    
    Sample output
    
    ```csv
    External API,07-11-2022 00:00,07-12-2022 08:25,29
    Internal API,07-11-2022 00:00,07-12-2022 08:25,29
    ```

- Sample output
  - [CSV](sample.csv)
  - [Text](sample.txt)

Remark: pending check for nodes, logging and monitoring certificates