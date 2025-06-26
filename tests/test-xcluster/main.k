
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-xcluster"
        spec = {
            assertResources: [
                # XNetwork for Azure networking
                platformazurev1alpha1.XNetwork{
                    metadata.name: "composite-network-aks"
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-cluster"
                            region: "westus"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
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
                # XAKS for Azure Kubernetes Service
                platformazurev1alpha1.XAKS{
                    metadata = {
                        name: "composite-cluster-aks"
                        labels = {
                            "xaks.azure.platform.upbound.io/cluster-id": "platform-ref-azure-cluster"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-cluster"
                            region: "westus"
                            deletionPolicy: "Delete"
                            providerConfigName: "default"
                            version: "1.31"
                            nodes = {
                                count: 1
                                instanceType: "Standard_B2s"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-azure-cluster-aks"
                            namespace: "default"
                        }
                    }
                },
                # XOss for observability stack
                observev1alpha1.XOss{
                    metadata.name: "composite-observability-oss"
                    spec = {
                        parameters = {
                            deletionPolicy: "Delete"
                            id: "platform-ref-azure-cluster"
                            operators = {
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                        }
                    }
                },
                # XFlux for GitOps
                gitopsv1alpha1.XFlux{
                    metadata.name: "composite-flux"
                    spec = {
                        parameters = {
                            deletionPolicy: "Delete"
                            providerConfigName: "platform-ref-azure-cluster"
                            operators = {
                                flux = {
                                    version: "2.10.6"
                                }
                                fluxSync = {
                                    version: "1.7.2"
                                }
                            }
                            source = {
                                git = {
                                    url: "https://github.com/upbound/platform-ref-azure/"
                                    ref = {
                                        name: "refs/heads/main"
                                    }
                                    interval: "5m0s"
                                    timeout: "60s"
                                    path: "/"
                                }
                            }
                        }
                    }
                },
                # Usage resources for deletion ordering (untyped objects)
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "usage-xeks-by-xflux"
                    spec = {
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "XFlux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "azure.platform.upbound.io/v1alpha1"
                            kind: "XAKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "usage-xeks-by-xoss"
                    spec = {
                        by = {
                            apiVersion: "observe.platform.upbound.io/v1alpha1"
                            kind: "XOss"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "azure.platform.upbound.io/v1alpha1"
                            kind: "XAKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                {
                    apiVersion: "apiextensions.crossplane.io/v1alpha1"
                    kind: "Usage"
                    metadata.name: "usage-xaks-by-arbitrary-labeled-release"
                    spec = {
                        by = {
                            apiVersion: "helm.crossplane.io/v1beta1"
                            kind: "Release"
                            resourceSelector = {
                                matchLabels = {
                                    "platform.upbound.io/deletion-ordering": "enabled"
                                }
                            }
                        }
                        of = {
                            apiVersion: "azure.platform.upbound.io/v1alpha1"
                            kind: "XAKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                }
            ]
            compositionPath: "apis/xclusters/composition.yaml"
            xrPath: "examples/xr-cluster.yaml"
            xrdPath: "apis/xclusters/definition.yaml"
            timeoutSeconds: 120
            validate: False
        }
    }
]
items = _items