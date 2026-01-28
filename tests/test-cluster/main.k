
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.gitops.v1alpha1 as gitopsv1alpha1
import models.io.upbound.platform.observe.v1alpha1 as observev1alpha1
import models.io.crossplane.protection.v1beta1 as protectionv1beta1

_items = [
    metav1alpha1.CompositionTest{
        metadata.name: "test-cluster"
        spec = {
            assertResources: [
                # Network for Azure networking
                platformazurev1alpha1.Network{
                    metadata.name: "composite-network-aks"
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-cluster"
                            region: "westus"
                            managementPolicies: ["*"]
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
                # AKS for Azure Kubernetes Service
                platformazurev1alpha1.AKS{
                    metadata = {
                        name: "composite-cluster-aks"
                        labels = {
                            "aks.azure.platform.upbound.io/cluster-id": "platform-ref-azure-cluster"
                        }
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-cluster"
                            region: "westus"
                            managementPolicies: ["*"]
                            providerConfigName: "default"
                            version: "1.34"
                            nodes = {
                                count: 1
                                instanceType: "Standard_B2s"
                            }
                        }
                    }
                },
                # Oss for observability stack
                observev1alpha1.Oss{
                    metadata.name: "composite-observability-oss"
                    spec = {
                        parameters = {
                            managementPolicies: ["*"]
                            id: "platform-ref-azure-cluster"
                            operators = {
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                        }
                    }
                },
                # Flux for GitOps
                gitopsv1alpha1.Flux{
                    metadata.name: "composite-flux"
                    spec = {
                        parameters = {
                            managementPolicies: ["*"]
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
                # Usage resources for deletion ordering (typed models)
                protectionv1beta1.Usage{
                    metadata = {
                        name: "usage-aks-by-flux"
                        namespace: "default"
                    }
                    spec = {
                        by = {
                            apiVersion: "gitops.platform.upbound.io/v1alpha1"
                            kind: "Flux"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "azure.platform.upbound.io/v1alpha1"
                            kind: "AKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                protectionv1beta1.Usage{
                    metadata = {
                        name: "usage-aks-by-oss"
                        namespace: "default"
                    }
                    spec = {
                        by = {
                            apiVersion: "observe.platform.upbound.io/v1alpha1"
                            kind: "Oss"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                        of = {
                            apiVersion: "azure.platform.upbound.io/v1alpha1"
                            kind: "AKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                },
                protectionv1beta1.Usage{
                    metadata = {
                        name: "usage-aks-by-arbitrary-labeled-release"
                        namespace: "default"
                    }
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
                            kind: "AKS"
                            resourceSelector = {
                                matchControllerRef: True
                            }
                        }
                    }
                }
            ]
            compositionPath: "apis/clusters/composition.yaml"
            xrPath: "examples/cluster-xr.yaml"
            xrdPath: "apis/clusters/definition.yaml"
            timeoutSeconds: 120
            validate: False
        }
    }
]
items = _items