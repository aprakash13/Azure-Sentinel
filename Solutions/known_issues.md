# Azure Sentinel Solutions Known Issues

## Known Issue #1 – Resource Group selection during solution Deployment
Azure Sentinel solutions deploy resources for Azure Sentinel scenarios. This means the resource group selected for deployment needs to have Azure Sentinel enabled for the deployment to succeed, specifically for Azure Sentinel resources like analytics rules, hunting queries etc. Hence do not select a ‘New’ resource group while deploying an Azure Sentinel solution as that would result in deployment failure as a new resource group would not have Azure Sentinel enabled by default. 

![Azure Sentinel solutions resource group selection](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Images/solutions_resource_group.png)

## Known Issue #2 – Solution Re-deployment
Redeploying or Reinstalling the same Solution creates duplicate content items in the respective feature galleries. The Solutions package includes content like analytic rules, workbooks etc. that gets saved in the Active rules gallery, saved workbooks gallery etc., respectively. Overwriting the content would mean loss in customizations if any to any content post Solution deployment. Hence, duplicate content items are created so that you can decide and delete the extraneous content as needed.
Refer to following screenshots as examples.
![Azure Sentinel solutions re-deployment analytics](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Images/solutions-reinstall-analytics.png)

![Azure Sentinel solutions re-deployment workbooks](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Images/solutions-reinstall-workbooks.png)

## Known Issue #3 – Content configuration and enablement 
If the Solution you’re deploying includes data connectors and associated content, enable the data connector and ensure the data type / tables are set and data is flowing before enabling related content like analytical rules or running hunting queries or workbooks that operate on that data. Usually after the data connector is enabled, it takes around 5-10 minutes for data to flow in Azure Sentinel / Azure Log Analytics.
For Azure Logic Apps playbooks configuration process during deployment, if you are unaware of the specific configuration values, you can enter invalid entries to proceed with successful deployment and then reconfigure with correct values in the playbooks gallery as needed so that the playbook runs are successful. 

## Known Issue #4 – Missing metadata information for content
Workbooks and Hunting queries deployed by Solutions may miss correct metadata information post deployment as illustrated in the screenshots below. However, this does not reduce the value the content is intended to deliver in terms of delivering the data monitoring and threat hunting capabilities in Azure Sentinel. 

![Azure Sentinel solutions missing metadata workbooks](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Images/solutions-missing-metadata-workbooks.png)

![Azure Sentinel solutions missing metadata hunting](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Images/solutions-missing-metadata-hunting.png)

## Known Issue #5 
A central option to uninstall all content associated with an Azure Sentinel Solution is not available. Content associated with a Solution can be deleted by exercising the delete option available in the respective galleries for each content type in alignment with the feature gallery UX support (some feature galleries may not provide a content delete option by design). 
