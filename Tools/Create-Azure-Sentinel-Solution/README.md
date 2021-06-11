# Azure Sentinel Solutions Packaging Tool Guidance

Azure Sentinel Solutions provide an in-product experience for central discoverability, single-step deployment, and enablement of end-to-end product and/or domain and/or vertical scenarios in Azure Sentinel. This experience is powered by Azure Marketplace for Solutions' discoverability, deployment and enablement and Microsoft Partner Center for Solutions’ authoring and publishing. Refer to details in [Azure Sentinel solutions documentation](https://aka.ms/azuresentinelsolutionsdoc). Detailed partner guidance for authoring and publishing solutions is covered in [building Azure Sentinel solutions guidance](https://aka.ms/sentinelsolutionsbuildguide). 

The packaging tool detailed below provides an easy way to generate your solution package of choice in an automated manner and enables validation of the package generated as well. You can package different types of Azure Sentinel content that includes a combination of data connectors, parsers or Kusto Functions, workbooks, analytic rules, hunting queries, Azure Logic apps custom connectors, playbooks and watchlists. 

## Setup

- Install PowerShell 7.1+

  - If you already have PowerShell 5.1, please follow this [upgrade guide](https://docs.microsoft.com/powershell/scripting/install/migrating-from-windows-powershell-51-to-powershell-7?view=powershell-7.1).

  - If you do not already have PowerShell, please follow this [installation guide](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7.1).

- Install Node.js

  - The installation process can be started from [their website](https://nodejs.org/).

- Install YAML Toolkit for Powershell

  - `Install-Module powershell-yaml`

- *For ease of editing, it's recommended to use VSCode with the 'Azure Resource Manager (ARM) Tools' extension installed*

  - Install [VSCode](https://code.visualstudio.com/).

  - Install the [Azure Resource Manager (ARM) Tools Extension](https://marketplace.visualstudio.com/items?itemName=msazurermtools.azurerm-vscode-tools).
  
    - This extension provides language support, resource auto-completion, and automatic template validation within your IDE.

## Creating Solution Package

Clone the repository [Azure-Sentinel](https://github.com/Azure/Azure-Sentinel) to `C:\One`.

### Create Input File

Create an input file and place it in the path `C:\One\Azure-Sentinel\Tools\Create-Sentinel-Solution\input`.

#### **Input File Format:**

```json
/**
 * Solution Automation Input File Json
 * -----------------------------------------------------
 * The purpose of this json is to provide detail on the various fields the input file can have.
 * Name: Solution Name - Ex. "Symantec Endpoint Protection"
 * Author: Author Name+Email of Solution - Ex. "Eli Forbes - v-eliforbes@microsoft.com"
 * Logo: Link to the Logo used in createUiDefinition.json
 * Description: Solution Description used in createUiDefinition.json. Can include markdown.
 * WorkbookDescription: Workbook description(s), generally from Workbooks Metadata. This field can be a string if 1 description is used, and an array if multiple are used.
 * Workbooks, Analytic Rules, Playbooks, etc.: These fields take arrays of paths relative to the repo  root, or BasePath if provided.
 * - NOTE: Playbooks field can take standard Playbooks, Custom Connectors, and Function Apps
 * BasePath: Optional base path to use. Either Internet URL or File Path. Default is repo root (https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/)
 * Version: Version to be used during package creation
 */
{
  "Name": "{SolutionName}",
  "Author": "{AuthorName - Email}",
  "Logo": "<img src=\"{LogoLink}\" width=\"75px\" height=\"75px\">",
  "Description": "{Solution Description}",
  "WorkbookDescription": ["{Description of workbook}"],
  "Workbooks": [],
  "Analytic Rules": [],
  "Playbooks": [],
  "Parsers": [],
  "Hunting Queries": [],
  "Data Connectors": [],
  "BasePath": "{Path to Solution Content}",
  "Version": "1.0.0"
}

```

#### **Example of Input File: Solution_McAfeePO.json**

```json
{
  "Name": "McAfeePO",
  "Author": "Eli Forbes - v-eliforbes@microsoft.com",
  "Logo": "<img src=\"https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Solutions/McAfeeePO/Workbooks/Images/Logo/mcafee_logo.svg\" width=\"75px\" height=\"75px\">",
  "Description": "The [McAfee ePO](https://www.mcafee.com/enterprise/en-in/products/epolicy-orchestrator.html) is a centralized policy management and enforcement for your endpoints and enterprise security products. McAfee ePO monitors and manages your network, detecting threats and protecting endpoints against these threats.",
  "WorkbookDescription": "Gain insights into McAfeePO logs.",
  "Workbooks": [
    "Workbooks/McAfeeePOOverview.json"
  ],
  "Analytic Rules": [
    "Analytic Rules/McAfeeEPOAgentHandlerDown.yaml",
    "Analytic Rules/McAfeeEPOAlertError.yaml"
  ],
  "Parsers": [
    "Parsers/McAfeeEPOEvent.txt "
  ],
  "Hunting Queries": [
    "Hunting Queries/McAfeeEPOAgentErrors.yaml"
  ],
  "Data Connectors": [
    "Data Connectors/Connector_McAfee_ePO.json"
  ],
  "BasePath": "https://raw.githubusercontent.com/Azure/Azure-Sentinel/master/Solutions/McAfeeePO/",
  "Version": "1.0.0"
}  
```

### Generate Solution Package

To generate the solution package from the given input file, run the `createSolution.ps1` script in the automation folder, `Tools/Create-Azure-Sentinel-Solution`.
> Ex. From repository root, run: `./Tools/Create-Azure-Sentinel-Solution/createSolution.ps1`

This will generate and compress the solution package, and name the package using the version provided in the input file.

The package consists of the following files:

* `createUIDefinition.json`: Template containing the definition for the Deployment Creation UI

* `mainTemplate.json`: Template containing Deployable Resources

These files will be created in the solution's `Package` folder with respect to the resources provided in the given input file. For every new modification to the files after the initial version of package, a new zip file should be created with an updated version name (1.0.1, 1.0.2, etc.) containing modified `createUIDefinition.json` and `mainTemplate.json` files.

Upon package creation, the automation will automatically import and run validation on the generated files using the Azure Toolkit / TTK CLI tool.

### Azure Toolkit Validation

The Azure Toolkit Validation is run automatically after package generation. However, if you make any manual edits to the template after the package is generated, you'll need to manually run the Azure Toolkit technical validation on your solution to check the end result.

If you've already run the package creation tool in your current PowerShell instance, you should have the validation command imported and available, otherwise follow the steps below to install.

#### Azure Toolkit Validation Setup

- Clone the [arm-ttk repository](https://github.com/Azure/arm-ttk) to `C:\One`
  - If `C:\One` does not exist, create the folder.
  - You may also choose a different folder, but properly reference it in the Profile script.
- Open your Powershell Profile script
  - To find your Powershell Profile Script:
    - Open Powershell.
    - Type `$profile`, and hit enter.
    - Your Powershell Profile script path will be output to the screen.
    - Open the Profile script.
- Add the following line of code to your Profile script.
  - `Import-Module C:\One\arm-ttk\arm-ttk\arm-ttk.psd1`
- Save and close your Profile script.
- Refresh your profile.
  - Run the following command in Powershell: `& $profile`
  - Alternatively, you can close and re-open your PowerShell window.

#### Azure Toolkit Validation Usage

- Navigate to the directory of your solution.
- Run: `Test-AzTemplate`

### Manual Validation

Once the package is created and Azure Toolkit technical validation is passing, one should manually validate that the package is created as desired.

**1. Validate createUiDefinition.json:**

* Open [CreateUISandbox](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/SandboxBlade).
* Copy json content from createUiDefinition.json (in the recent version).
* Clear that content in the editor and replace with copied content in step #2.
* Click on preview
* You should see the User Interface preview of data connector, workbook, etc., and descriptions you provided in input file.
* Check the description and User Interface of solution preview.

**2. Validate maintemplate.json:**

Validate `mainTemplate.json` by deploying the template in portal.
Follow these steps to deploy in portal:

* Open up <https://aka.ms/AzureSentinelPrP> which launches the Azure portal with the needed private preview flags.
* Go to "Deploy a Custom Template" on the portal
* Select "Build your own template in Editor".
* Copy json content from `mainTemplate.json` (in the recent version).
* Clear that content in the editor and replace with copied content in step #3.
* Click Save and then progress to selecting subscription, Sentinel-enabled resource group, and corresponding workspace, etc., to complete the deployment.
* Click Review + Create to trigger deployment.
* Check if the deployment successfully completes.
* You should see the data connector, workbook, etc., deployed in the respective galleries and validate – let us know your feedback.

### Known Failures

#### VMSizes Must Match Template

This will generally show as a warning but the test will be skipped. This will not be perceived as an error by the build.

### Common Issues

#### Template Should Not Contain Blanks

This issue most commonly comes from the serialized workbook and playbooks, due to certain properties in the json having values of null, [], or {}. To fix this, remove these properties.

#### IDs Should Be Derived from ResourceIDs

Some IDs used, most commonly in resources of type `Microsoft.Web/connections`, tend to throw this error despite seeming to fit the expected format. To fix this define two variables, one which uses the problematic ID value, and another which references the first variable, then use this second variable as necessary in place of the ID value. See below for example of such a variable pair:

```json
"variables": {
    "playbook-1-connection-1": "[concat('/subscriptions/', subscription().subscriptionId, '/providers/Microsoft.Web/locations/', parameters('workspace-location'), '/managedApis/microsoftgraphsecurity')]",
    "_playbook-1-connection-1": "[variables('playbook-1-connection-1')]"
  }
```

#### ApiVersions Should Be Recent

Some resources, particularly playbook-related resources, come in with outdated `apiVersion` properties, and depending on the version it may not be picked up as outdated by the validation.

Please ensure that resources of the following types use the corresponding versions:

```json
{
    "type": "Microsoft.Web/connections",
    "apiVersion": "2018-07-01-preview",
}
```

```json
{
    "type": "Microsoft.Logic/workflows",
    "apiVersion": "2019-05-01",
}
```

#### Parameters Must Be Referenced

It's possible some default parameters may go unused, especially if the solution consists mainly of playbooks. On failure this check will output the unused parameter(s) that exist within the `mainTemplate.json` file.

To fix this, remove the unused parameter from the `parameters` section of `mainTemplate.json`, and check the following common issue "Outputs Must Be Present In Template Parameters".

#### Outputs Must Be Present In Template Parameters

In most cases, this error is a result of removing an unused parameter reference from `mainTemplate.json`. To fix the error in such a case, remove the problematic output variable from the `outputs` section of `createUiDefinition.json`.

Otherwise, the parameter will need be added in the `parameters` section of `mainTemplate.json` and referenced as necessary.

#### Main Template Encoding Issues

If you generate your solution package using a version of PowerShell under 7.1, you'll likely face encoding errors which cause issues within the `mainTemplate.json` file.

The main encoding issue here will be that single-quote characters `'` are encoded into `\u0027`, and due to function references relying on single-quotes, this will break the template.

To resolve this issue, it's recommended that you install PowerShell 7.1+ and re-generate the package.

See [Setup](#setup) to install PowerShell 7.1+.


#### YAML Conversion Issues

If the YAML Toolkit for PowerShell is not installed, you may experience errors related to converting `.yaml` files, for analytic rules or otherwise.

To resolve this issue, it's recommended that you install the YAML Toolkit for Powershell.

See [Setup](#setup) to install the YAML Toolkit for PowerShell.
