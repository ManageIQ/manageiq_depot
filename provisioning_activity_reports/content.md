This is a package of 5 reports that you can use to report on provisioning activity over the current month, quarter, 
YTD, Previous month and Quarter.

The reports contain the following fields:
- Date Created 
- Approved By
- Approval State
- Description
- Destination Type
- Fulfilled On
- Region Number
- Type
- Userid

![Screen Shot Report Overview ](images/reportoverview_small.jpg)

To add the reports to your MIQ or CloudForms environment go to Cloud Intelligence and then Reports
![Screen Shot Reports Menu ](images/reports_menu.PNG)

Select Import/Export at the bottom left navigation.
![Screen Shot Import Menu ](images/import_menu.PNG)

Download the report yaml definitions for the reports you want to import.

- Download the [current month report here](scripts/Reports_Prov_Activity_CurrentMonth.yaml)
- Download the [current quarter report here](scripts/Reports_Prov_Activity_CurrentQuarter.yaml)
- Download the [previous month report here](scripts/Reports_Prov_Activity_PreviousMonth.yaml)
- Download the [previous quarter report here](scripts/Reports_Prov_Activity_PreviousQuarter.yaml)
- Download the [year to date report here](scripts/Reports_Prov_Activity_YTD.yaml)

Browse to the report yaml file that you want to upload.  Note you can only upload one at a time.
![Screen Shot Import ](images/import.PNG)

![Screen Shot Import Success](images/import_success.PNG)

Select Reports in the left hand navigation and you will see a blue folder with "Company Name (All EVM Groups)".  Under the custom sub-folder will be the imported report(s) that you can now run or schedule to run.

![Screen Shot Import Success](images/reports_list.PNG)

