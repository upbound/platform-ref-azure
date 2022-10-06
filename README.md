# Azure Reference Platform for Kubernetes + Data Services

This repository contains a reference Azure Platform
[Configuration](https://crossplane.io/docs/v1.6/getting-started/create-configuration.html)
for use as a starting point in [Upbound Cloud](https://upbound.io) or
[Upbound Universal Crossplane (UXP)](https://www.upbound.io/products/universal-crossplane) to build,
run and operate your own internal cloud platform and offer a self-service
console and API to your internal teams. It provides platform APIs to provision
fully configured Azure AKS clusters, with secure networking, and stateful cloud
services (Azure Database for PostgreSQL) designed to securely connect to the nodes in each AKS cluster --
all composed using cloud service primitives from the [Upbound Official Azure
Provider](https://marketplace.upbound.io/providers/upbound/provider-azure). App
deployments can securely connect to the infrastructure they need using secrets
distributed directly to the app namespace.

## Contents

* [Upbound Cloud](#upbound-cloud)
* [Build Your Own Internal Cloud Platform](#build-your-own-internal-cloud-platform)
* [Quick Start](#quick-start)
* [Platform Ops/SRE: Run your own internal cloud platform](#platform-opssre-run-your-own-internal-cloud-platform)
  * [App Dev/Ops: Consume the infrastructure you need using kubectl](#app-devops-consume-the-infrastructure-you-need-using-kubectl)
  * [APIs in this Configuration](#apis-in-this-configuration)
* [Customize for your Organization](#customize-for-your-organization)
* [Learn More](#learn-more)

## Upbound Cloud

![Upbound Overview](docs/media/upbound.png)

What if you could eliminate infrastructure bottlenecks, security pitfalls, and
deliver apps faster by providing your teams with self-service APIs that
encapsulate your best practices and security policies, so they can quickly
provision the infrastructure they need using a custom cloud console, `kubectl`,
or deployment pipelines and GitOps workflows -- all without writing code?

[Upbound Cloud](https://upbound.io) enables you to do just that, powered by the
open source [Upbound Universal Crossplane](https://www.upbound.io/products/universal-crossplane) project.

Consistent self-service APIs can be provided across dev, staging, and
production environments, making it easy for app teams to get the infrastructure
they need using vetted infrastructure configurations that meet the standards
of your organization.

## Build Your Own Internal Cloud Platform

App teams can provision the infrastructure they need with a single YAML file
alongside `Deployments` and `Services` using existing tools and workflows
including tools like `kubectl` and Flux to consume your platform's self-service
APIs.

The Platform `Configuration` defines the self-service APIs and
classes-of-service for each API:

* `CompositeResourceDefinitions` (XRDs) define the platform's self-service
   APIs - e.g. `CompositePostgreSQLInstance`.
* `Compositions` offer the classes-of-service supported for each self-service
   API - e.g. `Standard`, `Performance`, `Replicated`.

![Upbound Overview](docs/media/compose.png)

Crossplane `Providers` include the cloud service primitives (AWS, Azure, GCP,
Alibaba) used in a `Composition`.

Learn more about `Composition` in the [Crossplane
Docs](https://crossplane.io/docs/v1.9/concepts/composition.html).

## Quick Start

### Platform Ops/SRE: Run your own internal cloud platform

There are two ways to run Universal Crossplane:

1. Hosted on Upbound Cloud
1. Self-hosted on any Kubernetes cluster.

To provision the Azure Reference platform, you can pick the option that is best for you. 

We'll go through each option in the next sections.

### Upbound Cloud Hosted UXP Control Plane

Hosted Control planes are run on Upbound's cloud infrastructure and provide a restricted
Kubernetes API endpoint that can be accessed via `kubectl` or CI/CD systems.

#### Create a free account in Upbound Cloud

1. Sign up for [Upbound Cloud](https://cloud.upbound.io/register).
1. When you first create an Upbound Account, you can create an Organization

#### Create a Hosted UXP Control Plane in Upbound Cloud

Install the `up` cli:

`up` is the official CLI for interacting with Upbound Cloud and Universal Crossplane (UXP).

There are multiple ways to [install up cli](https://cloud.upbound.io/docs/cli/#install-script),
including Homebrew and Linux packages.

```console
curl -sL https://cli.upbound.io | sh

up login
```

1. Create a `Control Plane` in Upbound Cloud (e.g. dev, staging, or prod).
1. Connect `kubectl` to your `Control Plane` instance.
   * Click on your Control Plane
   * Select the *Connect Using CLI*
   * Paste the commands to configure your local `kubectl` context
   * Test your connectivity by running `kubectl get pods -n upbound-system`

#### Installing UXP on a Kubernetes Cluster

The other option is installing UXP into a Kubernetes cluster you manage using `up`, which
is the official CLI for interacting with Upbound Cloud and Universal Crossplane (UXP).

There are multiple ways to [install up cli](https://cloud.upbound.io/docs/cli/#install-script),
including Homebrew and Linux packages.

```console
curl -sL https://cli.upbound.io | sh
```

Ensure that your kubectl context is pointing to the correct cluster:

```console
kubectl config current-context
```

Install UXP into the `upbound-system` namespace:

```console
up uxp install
```

Validate the install using the following command:

```console
kubectl get all -n upbound-system
```

#### Install the Platform Configuration

```console
# Check the latest version available in https://marketplace.upbound.io/configurations/upbound/platform-ref-azure/
kubectl apply -f examples/configuration.yaml
kubectl get pkg
```

#### Configure Providers in your Platform

Refer to [official marketplace documentation](https://marketplace.upbound.io/providers/upbound/provider-azure/v0.13.0/docs/quickstart)

### We are now ready to provision resources:

#### Create AKS Cluster

The example cluster composition creates an AKS cluster and includes a nested composite resource for the network, which creates a Resource Group, Virtual Network, and Subnet:

```console
kubectl apply -f examples/cluster-claim.yaml
```

verify status:

```console
kubectl get claim
kubectl get composite
kubectl get managed
```

>_Note: you may see an error similar to this during AKS cluster provisioning: `Error: autorest/azure: Service returned an error. Status=409 Code="RoleAssignmentExists" Message="The role assignment already exists.` This is due to a known issue with the Azure API. The AKS cluster should successfully provision after Crossplane iterates the reconcile loop a few times._

#### Provision a PostgreSQLInstance using kubectl

```console
kubectl apply -f examples/postgres-claim.yaml
```

Verify status:

```console
kubectl get claim
kubectl get composite
kubectl get managed
```
Check your Azure Cloud portal to verify your infrastructure is created. Try changing the CIDR for the subnet and see if it is reconciled to intended state.

### Cleanup & Uninstall

#### Cleanup Resources

Delete resources created through the `Control Plane` Configurations menu:

```console
kubectl delete -f examples/postgres-claim.yaml
kubectl delete -f examples/cluster-claim.yaml
```

Verify all underlying resources have been cleanly deleted:

```console
kubectl get managed
```

#### Uninstall Provider & Platform Configuration

```console
kubectl delete configuration.pkg.crossplane.io upbound-platform-ref-azure
kubectl delete provider.pkg.crossplane.io crossplane-provider-azure
kubectl delete provider.pkg.crossplane.io crossplane-provider-helm
```

### Uninstall Azure App Registration

_Note: If you plan to continue testing with the Azure provider, perform this cleanup step later_

```console
AZ_APP_ID=$(az ad sp list --display-name platform-ref-azure)
az ad sp delete --id $AZ_APP_ID
```

## APIs in this Configuration

* `Cluster` - provision a fully configured AKS cluster
  * [definition.yaml](cluster/definition.yaml)
  * [composition.yaml](cluster/composition.yaml) includes (transitively):
    * `XAKS` for AKS cluster.
    * `XNetwork` for network fabric.
    * `XServices` for Prometheus and other cluster services.
* `XAKS` Creates AKS cluster.
  * [definition.yaml](cluster/aks/definition.yaml)
  * [composition.yaml](cluster/aks/composition.yaml) includes:
    * `AKSCluster` for Azure AKS cluster.
* `XNetwork` - fabric for a `Cluster` to securely connect to Data Services and
  the Internet.
  * [definition.yaml](cluster/network/definition.yaml)
  * [composition.yaml](cluster/network/composition.yaml) includes:
      * `ResourceGroup` Azure API.
      * `VirtualNetwork` Azure API.
      * `Subnet` Azure API.
* `XServices`
  * [definition.yaml](cluster/services/definition.yaml)
  * [composition.yaml](cluster/services/composition.yaml) includes:
    * `Release` Install Prometheus with the Helm provider Release API
* `PostgreSQLInstance` - provision an Azure Database for PostgreSQL instance that securely connects to a
  * [definition.yaml](database/postgres/definition.yaml)
  * [composition.yaml](database/postgres/composition.yaml) includes:
    * `PostgreSQLServer`
    * `PostgreSQLServerVirtualNetworkRule`

## Customize for your Organization

Create a `Repository` called `platform-ref-azure` in your Upbound Cloud `Organization`:

![](docs/media/repository-empty.png)

<br>

Set these to match your settings:

```console
UPBOUND_ORG=acme
UPBOUND_ACCOUNT_EMAIL=me@acme.com
REPO=platform-ref-azure
VERSION_TAG=v0.1.0
REGISTRY=xpkg.upbound.io
PLATFORM_CONFIG=${REGISTRY:+$REGISTRY/}${UPBOUND_ORG}/${REPO}:${VERSION_TAG}
```

Login to your container registry. _(Your password is the same as Upbound Cloud login.)_

```console
docker login ${REGISTRY} -u ${UPBOUND_ACCOUNT_EMAIL}
```

Build package.

```console
up xpkg build --name package.xpkg --package-root=package --examples-root="examples"
```

Push package to registry.

```console
up xpkg push ${PLATFORM_CONFIG} -f package.xpkg
```

![](docs/media/pushToRepo.png)


The Azure cloud service primitives that can be used in a `Composition` today are
listed in the [Upbound Official Azure Provider
Docs](https://marketplace.upbound.io/providers/upbound/provider-azure/).

To learn more see [Configuration
Packages](https://crossplane.io/docs/v1.9/concepts/packages.html#configuration-packages).

## What's Next

If you're interested in building your own reference platform for your company,
we'd love to hear from you and chat. You can set up some time with us at
info@upbound.io.

For Crossplane questions, drop by [slack.crossplane.io](https://slack.crossplane.io), and say hi!
