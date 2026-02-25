import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platformref.azure.v1alpha1 as platformrefv1alpha1
import models.io.crossplane.protection.v1beta1 as protectionv1beta1
import models.io.crossplane.helmm.v1beta1 as helmv1beta1

# Note: avoid casting the full OXR (e.g. Cluster{**oxr}) because the
# auto-generated model types status.conditions as a typed list which is
# incompatible with the generic list Crossplane passes at runtime.
# Instead, keep the raw OXR and cast only the sub-fields we need.
oxr = option("params").oxr
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
_params = platformrefv1alpha1.Cluster.spec.parameters{**oxr.spec?.parameters}

_metadata = lambda name: str -> any {
    {
        name = name
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
    }
}

# Extract parameters from the observed composite resource (XR)
_id = _params?.id
_region = _params?.region
_managementPolicies = _params?.managementPolicies or ["*"]
_providerConfigName = _params?.providerConfigName or "default"
_version = _params?.version
_nodeCount = _params?.nodes?.count or 1
_instanceType = _params?.nodes?.instanceType
_fluxVersion = _params?.operators?.flux?.version
_fluxSyncVersion = _params?.operators?.fluxSync?.version
_prometheusVersion = _params?.operators?.prometheus?.version
_gitops = _params?.gitops or {}

_items = [
    # Network - Azure networking infrastructure
    platformazurev1alpha1.Network{
        metadata: _metadata("composite-network-aks")
        spec: {
            parameters: {
                id: _id
                region: _region
                managementPolicies: _managementPolicies
                providerConfigName: _providerConfigName
                addressRange: "10.1.0.0/16"
                generalSubnetRange: "10.1.1.0/24"
                databaseSubnets: [
                    {
                        addressRange: "10.1.2.0/24"
                        serviceType: "mysql"
                    }
                ]
            }
        }
    },

    # AKS - Azure Kubernetes Service cluster
    platformazurev1alpha1.AKS{
        metadata: _metadata("composite-cluster-aks") | {
            labels: {
                "aks.azure.platform.upbound.io/cluster-id": _id
            }
        }
        spec: {
            parameters: {
                id: _id
                region: _region
                managementPolicies: _managementPolicies
                providerConfigName: _providerConfigName
                version: _version
                nodes: {
                    count: _nodeCount
                    instanceType: _instanceType
                }
            }
        }
    },

    # Oss - Observability stack (Prometheus)
    observev1alpha1.Oss{
        metadata: _metadata("composite-observability-oss")
        spec: {
            parameters: {
                managementPolicies: _managementPolicies
                id: _id
                operators: {
                    prometheus: {
                        version: _prometheusVersion
                    }
                }
            }
        }
    },

    # Flux - GitOps (Flux) deployment
    gitopsv1alpha1.Flux{
        metadata: _metadata("composite-flux")
        spec: {
            parameters: {
                managementPolicies: _managementPolicies
                providerConfigName: _id
                operators: {
                    flux: {
                        version: _fluxVersion
                    }
                    fluxSync: {
                        version: _fluxSyncVersion
                    }
                }
                source: {
                    git: _gitops?.git
                }
            }
        }
    },

    # Usage resources for proper deletion ordering
    protectionv1beta1.Usage{
        metadata: _metadata("usage-aks-by-flux") | {
            namespace: oxr.metadata.namespace
        }
        spec: {
            by: {
                apiVersion: "gitops.platform.upbound.io/v1alpha1"
                kind: "Flux"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "AKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    },
    protectionv1beta1.Usage{
        metadata: _metadata("usage-aks-by-oss") | {
            namespace: oxr.metadata.namespace
        }
        spec: {
            by: {
                apiVersion: "observe.platform.upbound.io/v1alpha1"
                kind: "Oss"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "AKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    },
    protectionv1beta1.Usage{
        metadata: _metadata("usage-aks-by-arbitrary-labeled-release") | {
            namespace: oxr.metadata.namespace
        }
        spec: {
            by: {
                apiVersion: "helm.m.crossplane.io/v1beta1"  # Namespaced helm API
                kind: "Release"
                resourceSelector: {
                    matchLabels: {
                        "platform.upbound.io/deletion-ordering": "enabled"
                    }
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "AKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    }
]
items = _items
