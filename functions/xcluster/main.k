import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.upbound.platformref.azure.v1alpha1 as platformrefv1alpha1

oxr = platformrefv1alpha1.XCluster{**option("params").oxr}
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { 
        name = name
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
    }
}

# Extract parameters from the observed composite resource (XR)
_id = oxr.spec?.parameters?.id or ""
_region = oxr.spec?.parameters?.region or ""
_deletionPolicy = oxr.spec?.parameters?.deletionPolicy or "Delete"
_providerConfigName = oxr.spec?.parameters?.providerConfigName or "default"
_version = oxr.spec?.parameters?.version or "1.31"
_nodeCount = oxr.spec?.parameters?.nodes?.count or 1
_instanceType = oxr.spec?.parameters?.nodes?.instanceType or "Standard_B2s"
_fluxVersion = oxr.spec?.parameters?.operators?.flux?.version or "2.10.6"
_fluxSyncVersion = oxr.spec?.parameters?.operators?.fluxSync?.version or "1.7.2"
_prometheusVersion = oxr.spec?.parameters?.operators?.prometheus?.version or "52.1.0"
_gitops = oxr.spec?.parameters?.gitops or {}

_items = [
    # XNetwork - Azure networking infrastructure
    platformazurev1alpha1.XNetwork{
        metadata: _metadata("composite-network-aks")
        spec: {
            parameters: {
                id: _id
                region: _region
                deletionPolicy: _deletionPolicy
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
    
    # XAKS - Azure Kubernetes Service cluster
    platformazurev1alpha1.XAKS{
        metadata: _metadata("composite-cluster-aks") | {
            labels: {
                "xaks.azure.platform.upbound.io/cluster-id": _id
            }
        }
        spec: {
            parameters: {
                id: _id
                region: _region
                deletionPolicy: _deletionPolicy
                providerConfigName: _providerConfigName
                version: _version
                nodes: {
                    count: _nodeCount
                    instanceType: _instanceType
                }
            }
            writeConnectionSecretToRef: {
                name: _id + "-aks"
                namespace: oxr.spec?.writeConnectionSecretToRef?.namespace
            }
        }
    },
    
    # XOss - Observability stack (Prometheus)
    observev1alpha1.XOss{
        metadata: _metadata("composite-observability-oss")
        spec: {
            parameters: {
                deletionPolicy: _deletionPolicy
                id: _id
                operators: {
                    prometheus: {
                        version: _prometheusVersion
                    }
                }
            }
        }
    },
    
    # XFlux - GitOps (Flux) deployment
    gitopsv1alpha1.XFlux{
        metadata: _metadata("composite-flux")
        spec: {
            parameters: {
                deletionPolicy: _deletionPolicy
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
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usage-xeks-by-xflux")
        spec: {
            by: {
                apiVersion: "gitops.platform.upbound.io/v1alpha1"
                kind: "XFlux"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "XAKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    },
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usage-xeks-by-xoss")
        spec: {
            by: {
                apiVersion: "observe.platform.upbound.io/v1alpha1"
                kind: "XOss"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "XAKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    },
    {
        apiVersion: "apiextensions.crossplane.io/v1alpha1"
        kind: "Usage"
        metadata: _metadata("usage-xaks-by-arbitrary-labeled-release")
        spec: {
            by: {
                apiVersion: "helm.crossplane.io/v1beta1"
                kind: "Release"
                resourceSelector: {
                    matchLabels: {
                        "platform.upbound.io/deletion-ordering": "enabled"
                    }
                }
            }
            of: {
                apiVersion: "azure.platform.upbound.io/v1alpha1"
                kind: "XAKS"
                resourceSelector: {
                    matchControllerRef: True
                }
            }
        }
    }
]
items = _items
