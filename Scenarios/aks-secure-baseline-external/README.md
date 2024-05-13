# Scenario: AKS - Public Cluster IP Restricted, with Azure Redis Cache, APGW for Containers, Prometheus and Grafana

This reference implementation is based on the *secure baseline infrastructure architecture*.

## Core architecture components

- Azure Kubernetes Service (AKS)
- Azure Virtual Networks (hub-spoke)
- Azure Bastion
- Azure Firewall
- Route Table (User defined routing)
- Azure Application Gateway for Containers
- Azure Key Vault
- Azure Private Endpoint
- Azure Private DNS Zones
- Log Analytics Workspace
- Azure Redis Cache
- Azure Container Registry
- Azure Storage
- Azure Policy (both built-in and custom)

**TODO:**

- Add availability zone support if available for all the services
- Add diagnostics settings for all the services
- Add azure policy rules
- Replace custom bicep modules with the public Azure Verified Modules
- Create Grafana dashboards for monitoring

## SKUs

This scenario tries to use the cheapest SKU available for each service. However, some features are only available on the higher tiers SKUs.
For example VNET Integration or Private Link/Endpoint support.

However, for enterprise usage we recommend a careful examination of all the services used and their limitations.

- Azure Kubernetes Service - **Standard_B4ms VMs**
- Azure Bastion - **Developer (Needs manual setup)**
- Azure Firewall - **Basic**
- Azure Application Gateway for Containers - **Price is per component**
- Azure Key Vault - **Standard**
- Azure Redis Cache - **C0**
- Azure Container Registry - **Basic**
- Azure Managed Grafana - **Essential**

## Deploy the reference implementation

This reference implementation is provided using Bicep and the Azure Developer CLI.
To deploy navigate to the `Scenarios/aks-secure-baseline-external` folder:

- Update the `main.bicepparam` file with the values you want to use.
- Run the following command:

```bash
azd up
```
