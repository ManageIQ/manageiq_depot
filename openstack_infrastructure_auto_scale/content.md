## Add Alert and Event for Auto-Scaling through Automate

Follow these steps to enable autoscaling:

* Enable the appropriate Server roles:
   * Go to Configure -> Configuration
   * Under 'Server Roles', select 'Automation Engine', 'Notifier', and all 'Capacity & Utilization' Roles.  Then save the form.
* Create the memory alert:
   * Go to Control -> Import/Export
   * Upload 'role_memory_usage.yaml' ([download](scripts/role_memory_usage.yaml)) using the Import form and commit the import
   * Go to Control -> Explorer
   * In the left navigation select Alerts, and then click on 'InstackAutoscale: Total Allocated Memory % Used > 50'
      * Note that the comparison operator is '<' instead of '>'; this is due to a Ceilometer bug that reports inverse usage 
* Create an alert profile with the imported alert:
   * Go to Control -> Explorer
   * In the left navigation select Alert Profiles -> Cluster/Deployment Role Alert Profiles
   * Under Configuration, choose to Add a New Cluster/Deployment Role Alert Profile
      * Use ComputeMemoryCheck as the description, and select the InstackAutoscale alert; then submit the form
   * Click on the new ComputeMemoryCheck alert profile; under Configuration select 'Edit assignments for this Alert Profile'
      * Choose to assign the Alert Profile to 'Selected Cluster / Deployment Roles'; then select 'overcloud NovaCompute' and submit the form
* Create Automate action:
   * Go to Automate -> Import/Export
   * Upload 'autoscale_datastore.zip' ([download](scripts/autoscale_datastore.zip)) using the Import form
   * Toggle All namespaces and submit the form
   * Go to Automate -> Explorer
   * In the left navigation select Datastore, then select Instack
   * Under Configuration, choose 'Edit this Domain'; toggle 'Enabled' and submit the form
