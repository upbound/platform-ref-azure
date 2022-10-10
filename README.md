# Azure Reference Platform for Kubernetes + Data Services

This repository contains a reference Azure Platform
[Configuration](https://crossplane.io/docs/v1.9/getting-started/create-configuration)
for use as a starting point in working with [Upbound Universal Crossplane (UXP)](https://www.upbound.io/products/universal-crossplane)
and publishing to [Universal Marketplace](https://marketplace.upbound.io/).
It enables you to build, run and operate your own internal cloud platform and offer a self-service API to your internal teams.
It provides platform APIs to provision
fully configured Azure AKS clusters, with secure networking, and stateful cloud
services (Azure Database for PostgreSQL) designed to securely connect to the nodes in each AKS cluster --
all composed using cloud service primitives from the [Upbound Official Azure
Provider](https://marketplace.upbound.io/providers/upbound/provider-azure). App
deployments can securely connect to the infrastructure they need using secrets
distributed directly to the app namespace.

## Contents

* [Universal Crossplane and Universal Marketplace](#universal-crossplane-and-universal-marketplace)
* [Build Your Own Internal Cloud Platform](#build-your-own-internal-cloud-platform)
* [Platform Ops/SRE: Run your own internal cloud platform](#platform-opssre-run-your-own-internal-cloud-platform)
  * [App Dev/Ops: Consume the infrastructure you need using kubectl](#app-devops-consume-the-infrastructure-you-need-using-kubectl)
  * [APIs in this Configuration](#apis-in-this-configuration)
* [Customize for your Organization](#customize-for-your-organization)
* [Learn More](#learn-more)

## Universal Crossplane and Universal Marketplace

![Upbound Overview](docs/media/upbound.png)

What if you could eliminate infrastructure bottlenecks, security pitfalls, and
deliver apps faster by providing your teams with self-service APIs that
encapsulate your best practices and security policies, so they can quickly
provision the infrastructure they need using a custom cloud console, `kubectl`,
or deployment pipelines and GitOps workflows -- all without writing code?

[Upbound](https://upbound.io) enables you to do just that, powered by the
open source [Upbound Universal Crossplane](https://www.upbound.io/products/universal-crossplane) project.

The [Universal Marketplace](https://marketplace.upbound.io/) is a central hub for
finding Crossplane packages with verified content and auto-generated documentation.

Consistent self-service APIs can be provided across dev, staging, and
production environments, making it easy for app teams to get the infrastructure
they need using vetted infrastructure configurations that meet the standards
of your organization.

## Pre-Requisites

Install the following command line tools:

* `up cli`

  There are multiple ways to [install up](https://cloud.upbound.io/docs/cli/#install-script), including Homebrew and Linux packages.

  ```console
  curl -sL https://cli.upbound.io | sh

  ```

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
Docs](https://crossplane.io/docs/v1.9/concepts/composition).

## Platform Ops/SRE: Run your own internal cloud platform

The Universal Crossplane (UXP) can be provisioned to any Kubernetes cluster.

The Azure Reference platform will extend Kubernetes API with your own platform API
abstractions.

#### Installing UXP on a Kubernetes Cluster

You can install UXP into a Kubernetes cluster you manage using `up`, which
is the official CLI for interacting with Upbound Cloud and Universal Crossplane (UXP).

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

The alternative way of installation would be a standard helm, see https://github.com/upbound/universal-crossplane#installation-with-helm-3

#### Install the Platform Configuration

Now that your kubectl context is configured to connect to a UXP Control Plane,
we can install this reference platform as a Crossplane package.

```console
# Check the latest version available in https://marketplace.upbound.io/configurations/upbound/platform-ref-azure/
kubectl apply -f examples/configuration.yaml
kubectl get pkg
```

#### Configure Providers in your Platform

Refer to [official marketplace documentation](https://marketplace.upbound.io/providers/upbound/provider-azure/latest/docs/quickstart)

## Provision Resources

With the setup complete, we can now use platform-azure to provision resources in Azure cloud.

#### Create AKS Cluster

The example cluster composition creates an AKS cluster and includes a nested composite resource for the network, which creates a Resource Group, Virtual Network, and Subnet:

```console
kubectl apply -f examples/cluster-claim.yaml
```

Verify status:

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

## APIs in this Configuration

* `Cluster` - provision a fully configured AKS cluster
  * [definition.yaml](package/cluster/definition.yaml)
  * [composition.yaml](package/cluster/composition.yaml) includes (transitively):
    * `XAKS` for AKS cluster.
    * `XNetwork` for network fabric.
    * `XServices` for Prometheus and other cluster services.
* `XAKS` Creates AKS cluster.
  * [definition.yaml](package/cluster/aks/definition.yaml)
  * [composition.yaml](package/cluster/aks/composition.yaml) includes:
    * `KubernetesCluster` for Azure AKS cluster.
    * `ProviderConfig` of Helm Provider to install custom cluster services as
      a part of `XServices` abstraction
* `XNetwork` - fabric for a `Cluster` to securely connect to Data Services and
  the Internet.
  * [definition.yaml](package/cluster/network/definition.yaml)
  * [composition.yaml](package/cluster/network/composition.yaml) includes:
      * `ResourceGroup` Azure API.
      * `VirtualNetwork` Azure API.
      * `Subnet` Azure API.
* `XServices`
  * [definition.yaml](package/cluster/services/definition.yaml)
  * [composition.yaml](package/cluster/services/composition.yaml) includes:
    * `Release` Install Prometheus with the Helm provider Release API.
* `PostgreSQLInstance` - provision an Azure Database for PostgreSQL instance that securely connects to a
  * [definition.yaml](package/database/postgres/definition.yaml)
  * [composition.yaml](package/database/postgres/composition.yaml) includes:
    * `Server` - Azure PostgreSQL Single Server.
    * `VirtualNetworkRule` - PostgreSQL Virtual Network Rule.

## Customize for your Organization

You can customize this platform reference as much as you like and use it as
a foundation for building your very own Configuration.

In addition to that, you can create a free repository for your Configuration and
publish it to [Universal Marketplace](https://marketplace.upbound.io/)

### Create a free account in Upbound Cloud

1. Sign up for [Upbound Cloud](https://cloud.upbound.io/register).
1. When you first create an Upbound Account, you can create an Organization

### Create a Custom Repository

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

Install package into an Universal Crossplane(UXP) instance.

```console
cat <<EOF >> configuration.yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: platform-ref-azure
spec:
  package: ${PLATFORM_CONFIG}
EOF
```

```console
kubectl apply -f configuration.yaml
```

The Azure cloud service primitives that can be used in a `Composition` today are
listed in the [Upbound Official Azure Provider
Docs](https://marketplace.upbound.io/providers/upbound/provider-azure/).

To learn more see [Configuration
Packages](https://crossplane.io/docs/v1.9/concepts/packages#configuration-packages).

## What's Next

If you're interested in building your own reference platform for your company,
we'd love to hear from you and chat. You can set up some time with us at
https://www.upbound.io/contact

For Crossplane questions, drop by [slack.crossplane.io](https://slack.crossplane.io), and say hi!
