# This script will create a Managed Application from the Azure/WordPress ARM template
# see https://github.com/Azure/WordPress/tree/master/managedApplication

# Application Configuration

export VERSION_NUMBER=1
export WP_MANAGED_APP_DISPLAY_NAME=WordPressManagedApp
export WP_MANAGED_APP_NAME=WPManagedApp_$(whoami)_$VERSION_NUMBER
export WP_MANAGED_APP_DESCRIPTION="Testing the WordPress ARM template as a managed application."
export WP_MANAGED_APP_OWNER_GROUP_NAME=$WP_MANAGED_APP_NAME
export WP_MANAGED_APP_OWNER_NICKNAME=$WP_MANAGED_APP_NAME
export WP_SERVICE_CATALOG_RG_NAME=Catalog_RG_$WP_MANAGED_APP_NAME
#export WP_MANAGED_APP_LOCK_LEVEL=ReadOnly
#A lock level of None allows resources in the deployed Resource Group to be manipulated by the end user
export WP_MANAGED_APP_LOCK_LEVEL=None
export WP_SERVICE_CATALOG_LOCATION=WestUS

export PATH_TO_ARM_TEMPLATE=azuredeploy.json
export PATH_TO_WP_CREATEUI_DEF=createUIDefinition.json

# Publish A Managed Application To Service Catalog

# AD Config

echo "Configuring AD"

echo "Getting Application AD ID for $WP_MANAGED_APP_OWNER_GROUP_NAME"

WP_MANAGED_APP_AD_ID=$(az ad group list --display-name=$WP_MANAGED_APP_OWNER_GROUP_NAME --query [0].objectId --output tsv)

# The following line should create a new group, if necessary, but it fails with insufficient permissions
# if [ -z "$WP_MANAGED_APP_AD_ID" ]; then az ad group create --display-name $WP_MANAGED_APP_OWNER_GROUP_NAME --mail-nickname=$WP_MANAGED_APP_OWNER_NICKNAME; fi
# Not sure how to fix it so, for now tell user to create in portal, which works fine
if [ -z "$WP_MANAGED_APP_AD_ID" ]
then
    echo "AD group doesn't exist.\n"
    echo "There's a bug in the script which prevents this being automated (see comments, should be fixable by someone who knows)\n"
    echo "For now, you need to create an ad group with the name $WP_MANAGED_APP_OWNER_GROUP_NAME and owner $WP_MANAGED_APP_OWNER_NICKNAME see https://ms.portal.azure.com/#blade/Microsoft_AAD_IAM/GroupsManagementMenuBlade/AllGroups"
    read -p "Press any key when done... " -n1 -s;
    echo "Continuing..."
    WP_MANAGED_APP_AD_ID=$(az ad group list --display-name=$WP_MANAGED_APP_OWNER_GROUP_NAME --query [0].objectId --output tsv)
fi

if [ -z "$WP_MANAGED_APP_AD_ID"]
then
    >&2 echo "Failed to get a Managed App AD ID. If you just created this it may be that it is still propagating. Rerun the script."
    exit 1
else
    echo "Managed App AD ID is $WP_MANAGED_APP_AD_ID"
fi

WP_MANAGED_APP_ROLE_ID=$(az role definition list --name Owner --query [].name --output tsv)

echo "Managed App Role ID is $WP_MANAGED_APP_ROLE_ID"

# Create a Resource Group

echo "Creating the resource group for the service catalog using the name $WP_SERVICE_CATALOG_RG_NAME and location $WP_SERVICE_CATALOG_LOCATION"

az group create --name $WP_SERVICE_CATALOG_RG_NAME --location $WP_SERVICE_CATALOG_LOCATION

# Publish to the Service Catalog

echo "Publishing the application to the service catalog using the name $WP_MANAGED_APP_NAME"

WP_MANAGED_APP_AUTHORIZATIONS=$WP_MANAGED_APP_AD_ID:$WP_MANAGED_APP_ROLE_ID

az managedapp definition create \
    --name $WP_MANAGED_APP_NAME \
    --location $WP_SERVICE_CATALOG_LOCATION \
    --resource-group $WP_SERVICE_CATALOG_RG_NAME \
    --lock-level $WP_MANAGED_APP_LOCK_LEVEL \
    --display-name $WP_MANAGED_APP_DISPLAY_NAME \
    --description "$WP_MANAGED_APP_DESCRIPTION" \
    --authorizations="$WP_MANAGED_APP_AUTHORIZATIONS" \
    --main-template=@$PATH_TO_ARM_TEMPLATE \
    --create-ui-definition=@$PATH_TO_WP_CREATEUI_DEF


WP_MANAGED_APP_ID=$(az managedapp definition show --name $WP_MANAGED_APP_NAME --resource-group $WP_SERVICE_CATALOG_RG_NAME --query id --output tsv)

echo
echo "###############################################################"
echo "Assuming no errors reporteed above, you can now deploy an application in the portal at https://ms.portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Solutions%2FapplicationDefinitions"
echo "###############################################################"
