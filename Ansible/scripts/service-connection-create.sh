#!/bin/bash
#This script creates a Kubeconfig service connection for a cluster
#Prerequisites: yq package, Project Collection Build Service with Admin permissions over service endpoints

#Set variable names
AKS_NAME=$1
RG_NAME=$2
ORG=$3
PROJECT=$4

#Fetch Kubeconfig
az aks get-credentials --name "${AKS_NAME}" --resource-group "${RG_NAME}" --admin --file kubeconfig-temp

#Set additional variables
KUBECONFIG=$(yq eval -j -I=0 kubeconfig-temp | sed 's/\"//g')
AKS_URL=$(cat kubeconfig-temp | grep server | cut -f 3- -d ":" | tr -d "/n" | tr -d "\r")

#Replace values in json
awk -v AKS_NAME="${AKS_NAME}" -v AKS_URL="${AKS_URL}" -v KUBECONFIG="${KUBECONFIG}" '{
    sub(/{AKS_NAME}/, AKS_NAME);
    sub(/{AKS_URL}/, AKS_URL);
    sub(/{KUBECONFIG}/, KUBECONFIG);
    print;
}' service-connection-template.json > service-connection.json

#Check that az devops cli is installed
az extension add --name azure-devops

#Create service connection
az devops service-endpoint create --org "${ORG}" --project "${PROJECT}" --service-endpoint-configuration "service-connection.json"

#Update service connection
ID=$(az devops service-endpoint list --org "${ORG}" --project "${PROJECT}" --query "[?name=='Kubeconfig-${AKS_NAME}'].id" -o tsv)
az devops service-endpoint update --org "${ORG}" --project "${PROJECT}" --id "${ID}" --enable-for-all true

#Delete created files
rm service-connection.json
rm kubeconfig-temp
