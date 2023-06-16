# Azure Automation GUI

A Web App front end for Azure Automation Runbooks. Use this project as a starting point for developing custom interfaces to trigger automation tasks. Based on the [Azure Static Web Apps](https://learn.microsoft.com/en-us/azure/static-web-apps/overview) (SWA) Free plan.

![Automation GUI](extras/images/runbook-large.png)

## Creation

Steps to create the example application.

### Resource Deployment

1. Fork this repository in Github. It can be made private if wanted.
2. Create a Resource Group in Azure as a target for the ARM template deployment. These steps use a group named `automation-gui-example`.
3. Assign a Managed Identity permissions to create an App Registration with the following steps. This is used by the ARM template during deployment.

    1. Open a PowerShell Cloud Shell session and run the commands below to create the Managed Identity in the Resource Group.
    
    ```powershell
    $ResourceGroup = Get-AzResourceGroup -Name 'automation-gui-example'
    $Identity = New-AzUserAssignedIdentity -Name 'automation-gui-deploy-identity' -ResourceGroupName 'automation-gui-example' -Location $ResourceGroup.Location
    ```
    
    > **Note**
    > If the error "The subscription is not registered to use namespace 'Microsoft.ManagedIdentity'" is raised the "Microsoft.ManagedIdentity" provider will need to be registered under _Subscriptions > Resource providers_.
    
    2. Wait for the identity to appear in the portal (click refresh to check), then run the commands below in the same Cloud Shell session. There should be no errors raised.
    
    ```powershell
    Connect-AzureAD
    $ManagedSp = Get-AzADServicePrincipal -Filter "displayName eq '$($Identity.Name)'"
    $GraphSp = Get-AzADServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"
    
    $Permissions = @('Application.ReadWrite.OwnedBy', 'Directory.Read.All')
    $AppRoles = $GraphSp.AppRole | ?{($_.Value -in $Permissions) -and ($_.AllowedMemberType -contains 'Application')}
    $AppRoles | %{New-AzureAdServiceAppRoleAssignment -ObjectId $ManagedSp.Id -PrincipalId $ManagedSp.Id -ResourceId $GraphSp.Id -Id $_.Id}
    ```

4. Click the deploy to Azure button to start a Custom Deployment in Azure. The Resource Group created previously should be the target of the deployment.

    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchrisred%2Faz-automation-gui-example%2Fmaster%2Fextras%2Farm-automation-gui-example.jsonc)

5. Once the resources are deployed successfully follow the steps to [deploy the app](#app-deployment) with Github Actions.

### Template Parameters

Default values are assigned for most of the template parameters. The default values can be changed if wanted; except that the "Deployment Script Identity Name" must match the name given to the `New-AzUserAssignedIdentity` command in step 3, and the "Automation Webhook Expiry Time" must be an expression that sets a date in the future (1 year using the default).

### App Deployment

1. In Azure navigate to the Static Web App resource, click on "Manage Deployment Token" and copy it.
2. In Github access the settings of the forked repository, navigate to _Secrets and Variables > Actions_. Create a new Repository Secret named `AZURE_STATIC_WEB_APPS_API_TOKEN` and set the value to the token copied in step 1.
3. Still in Github click on `staticwebapp.config.json` in the root of the repository and use the "Edit this file" option to open the editor.
4. The `allowedRoles` property is an empty array. Add either `anonymous` or `authenticated` to the array, `authenticated` will enable Azure AD authentication, `anonymous` allows unauthenticated access. For example: `"allowedRoles": ["anonymous"]`. See the section on [Invitations](#roles-and-invitations) for restricting access to approved users only.
5. Click "Commit changes..", use the "Commit directly to the `master` branch" option. Github appears to treat this commit as a push, so it should trigger the Action to build and deploy the Static Web App.
6. After the Action has completed the visit the site at the unique domain name Azure assigns. This can be found in the Static Web App resource overview.

> **Note**
> When authentication is used the Static Web App resource will request consent to access basic AAD account details, the data can be removed with [this process](https://learn.microsoft.com/en-us/azure/static-web-apps/authentication-authorization#remove-personal-data).

### Hybrid Runbook Setup

Hybrid jobs can run on an Azure VM, or on an externally hosted server when it is connected using Azure Arc. This is one method to access services or data not managed by Azure.

The example creates a local Windows user account and syncs the local group names to an Azure Table so the "User Groups" drop-down list component can be populated. A Windows based Hybrid Worker is required to execute the jobs.

1. If using an external server follow the instructions to [add a server to Azure Arc](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-portal). This can be skipped for Azure hosted VMs.
2. Configure the server as a Hybrid Worker by [adding it to a Hybrid Worker group](https://learn.microsoft.com/en-us/azure/automation/extension-based-hybrid-runbook-worker-install#add-a-machine-to-a-hybrid-worker-group). A group named `automation-gui-example-[suffix]` is already present in the Automation Account.
3. Start the Runbook named `automation-gui-example-sync`. Provide the name of the Resource Group and the Storage Account as parameters, and run it on the Hybrid Worker. Check the job status to ensure it ran successfully.
4. Refresh the site to pickup the change, now the "Hybrid Runbook" option on the site can be used and should create a local user.

### Re-deploying the ARM Template

The following steps will remove the resources and allow the template to be re-deployed.

1. Remove the Hybrid Worker from the group if one was used, this will make sure the extension is uninstalled correctly.
2. Delete all the resources except for the Managed Identity (`automation-gui-deploy-identity`).
3. Remove the `Reader` and `Reader and Data Access` role assignments under "Access control" on the Resource Group.
4. Delete the App Registration.
5. The template can now be deployed to the same Resource Group again.

### Roles and Invitations

With the Free plan authenticated access is managed by [Roles and Invitations](https://learn.microsoft.com/en-us/azure/static-web-apps/authentication-custom#add-a-user-to-a-role). For example, in `staticwebapp.config.json` configure the `allowedRoles` property with a custom role as follows:

```json
"allowedRoles": ["invited"]
```

Now for a user to access the site they must first be provided an invitation link that assigns the "invited" role.

## Development

Steps to setup a basic development environment on Linux (tested with Fedora). [Vue.js](https://vuejs.org/) and [Vuetify](https://vuetifyjs.com/) are used to build the SWA, the Azure Functions API uses [Python](https://www.python.org/).

Windows is not covered here, however after the prerequisites are installed the setup should be similar.

### Prerequisites

Node.js, npm, Python 3.9 and Podman (or Docker) are required. For example:

```sh
sudo dnf install npm python3.9 podman
```

### Setup

1. Make a local clone (`git clone`) of the forked repository created in the [deployment](#resource-deployment) steps.
2. `cd` to the `az-automation-gui-example` directory.
3. Run `npm install` to install the Node.js package dependencies.
4. Run `python3.9 -m venv api/.venv` to create a Python virtual environment (venv) for the Azure Functions API.
5. Activate the venv with `source api/.venv/bin/activate`.
6. Run `pip install -r api/requirements.txt` to install the Python package dependencies.
7. Use the container option to run the [Azurite storage emulator](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=docker-hub), and set a folder with `-v` to save the Azurite data into. For example:

    ```sh
    podman pull mcr.microsoft.com/azure-storage/azurite
    podman run -p 10000:10000 -p 10001:10001 -p 10002:10002 -v /my/data/path/here:/data:z mcr.microsoft.com/azure-storage/azurite
    ```

    The `:z` suffix in the volume path correctly labels the mount point when using SELinux and avoids permission errors.

8. Create a development config for the Azure Function API at `api/local.settings.json`. The file should include the following contents, with any empty/example values replaced. For reference, the live version of these settings are stored by the Static Web App at _Configuration > Application Settings_.

    ```json
    {
      "IsEncrypted": false,
      "Values": {
        "FUNCTIONS_WORKER_RUNTIME": "python",
        "AZURE_SUBSCRIPTION_ID": "",
        "AZURE_TENANT_ID": "",
        "AZURE_CLIENT_ID": "",
        "AZURE_CLIENT_SECRET": "",
        "AUTOMATION_GROUP_NAME": "my-resource-group-name",
        "AUTOMATION_ACCOUNT_NAME": "my-automation-account-name",
        "WEBHOOK_RUNBOOK": "https://my-webhook-url.example.com",
        "WEBHOOK_HYBRID": "https://my-webhook-url.example.com",
        "STORAGE_CONNECTION_STRING": "UseDevelopmentStorage=true"
      }
    }
    ```

### Testing

The [SWA CLI](https://azure.github.io/static-web-apps-cli/docs/cli/swa) tool is used to emulate the Static Web App locally. This automatically uses the [Azure Functions Core Tools](https://learn.microsoft.com/en-us/azure/azure-functions/functions-core-tools-reference) to emulate Functions.

* `npx swa start http://localhost:5173 --run "npm run dev" --api-location api` runs the SWA directly from the Vite development server (Vite uses port `5173` by default). Use this to get the Vue.js hot reload feature to work.
* `npx swa build az-automation-gui` builds/bundles all the source files. 
* `npx swa start ./dist --api-location api` starts the SWA emulator using the bundled files in `./dist`.
* Ensure the Python "venv" is active when running the emulator so the correct python version and packages are available.

With either method the emulated SWA site will be available at `http://localhost:4280`.

### Test Data

[Azure Storage Explorer](https://azure.microsoft.com/en-us/products/storage/storage-explorer/) can connect to an emulated storage account. There a "Local storage emulator" option when adding an account. The [well-known storage account and key](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=docker-hub#authorization-for-tools-and-sdks) are used to authenticate.

Using Storage Explorer any test data required can be populated.
