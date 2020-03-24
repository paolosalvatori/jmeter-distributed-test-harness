#!/bin/bash

# JMeter distributed testing leverages multiple systems to perform load testing. 
# Distributed testing can be used to sping up a large amount of concurrent virtual users 
# and generate traffic aginst websites and server applications. For more information, see
# https://jmeter.apache.org/usermanual/jmeter_distributed_testing_step_by_step.html

# Variables
resourceGroupName="JMeterTestHarnessRG"
location="WestEurope"
deploy=1

# ARM template and parameters files
template="../templates/azuredeploy.json"
parameters="../templates/azuredeploy.parameters.json"

# SubscriptionId of the current subscription
subscriptionId=$(az account show --query id --output tsv)

# Check if the resource group already exists
createResourceGroup() {
    rg=$1

    echo "Checking if [$rg] resource group actually exists in the [$subscriptionId] subscription..."

    if ! az group show --name "$rg" &>/dev/null; then
        echo "No [$rg] resource group actually exists in the [$subscriptionId] subscription"
        echo "Creating [$rg] resource group in the [$subscriptionId] subscription..."

        # Create the resource group
        if az group create --name "$rg" --location "$location" 1>/dev/null; then
            echo "[$rg] resource group successfully created in the [$subscriptionId] subscription"
        else
            echo "Failed to create [$rg] resource group in the [$subscriptionId] subscription"
            exit 1
        fi
    else
        echo "[$rg] resource group already exists in the [$subscriptionId] subscription"
    fi
}

# Validate the ARM template
validateTemplate() {
    resourceGroup=$1
    template=$2
    parameters=$3
    arguments=$4

    echo "Validating [$template] ARM template..."

    if [[ -z $arguments ]]; then
        error=$(az group deployment validate \
            --resource-group "$resourceGroup" \
            --template-file "$template" \
            --parameters "$parameters" \
            --query error \
            --output json)
    else
        error=$(az group deployment validate \
            --resource-group "$resourceGroup" \
            --template-file "$template" \
            --parameters "$parameters" \
            --arguments $arguments \
            --query error \
            --output json)
    fi

    if [[ -z $error ]]; then
        echo "[$template] ARM template successfully validated"
    else
        echo "Failed to validate the [$template] ARM template"
        echo "$error"
        exit 1
    fi
}

# Deploy ARM template
deployTemplate() {
    resourceGroup=$1
    template=$2
    parameters=$3
    arguments=$4

    if [ $deploy != 1 ]; then
        return
    fi
    # Deploy the ARM template
    echo "Deploying ["$template"] ARM template..."

    if [[ -z $arguments ]]; then
        az group deployment create \
            --resource-group $resourceGroup \
            --template-file $template \
            --parameters $parameters 1>/dev/null
    else
        az group deployment create \
            --resource-group $resourceGroup \
            --template-file $template \
            --parameters $parameters \
            --parameters $arguments 1>/dev/null
    fi

    az group deployment create \
        --resource-group $resourceGroup \
        --template-file $template \
        --parameters $parameters 1>/dev/null

    if [[ $? == 0 ]]; then
        echo "["$template"] ARM template successfully provisioned"
    else
        echo "Failed to provision the ["$template"] ARM template"
        exit -1
    fi
}

# Create Resource Group
createResourceGroup "$resourceGroupName"

# Deploy JMeter Test Harness
deployTemplate \
    "$resourceGroupName" \
    "$template" \
    "$parameters"