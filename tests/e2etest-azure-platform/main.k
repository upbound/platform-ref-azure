import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.v1alpha1 as platformv1alpha1
import models.io.upbound.platformref.azure.v1alpha1 as platformrefazurev1alpha1
import models.io.upbound.azure.v1beta1 as azurev1beta1

_items = [
    metav1alpha1.E2ETest{
        metadata.name: "azure-platform-e2e"
        spec = {
            crossplane = {
                autoUpgrade = {
                    channel: "Rapid"
                }
            }
            defaultConditions: ["Ready"]
            manifests: [
                # 1. Cluster claim (AKS + networking + observability + GitOps)
                platformrefazurev1alpha1.XCluster{
                    metadata = {
                        name: "platform-ref-azure-cluster"
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-cluster"
                            region: "westeurope"
                            version: "1.31"
                            nodes = {
                                count: 1
                                instanceType: "Standard_B2s"
                            }
                            operators = {
                                flux = {
                                    version: "2.10.6"
                                }
                                fluxSync = {
                                    version: "1.7.2"
                                }
                                prometheus = {
                                    version: "52.1.0"
                                }
                            }
                            gitops = {
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
                        writeConnectionSecretToRef = {
                            name: "platform-ref-azure-cluster-kubeconfig"
                            namespace: "default"
                        }
                    }
                },

                # 2. Database claim (MySQL)
                platformazurev1alpha1.XSQLInstance{
                    metadata = {
                        name: "platform-ref-azure-cluster-db-mysql"
                    }
                    spec = {
                        compositionSelector = {
                            matchLabels = {
                                dbengine: "mysql"
                            }
                        }
                        parameters = {
                            region: "westeurope"
                            storageGB: 20  # Minimum 20 GB for MySQL
                            version: "8.0"
                            passwordSecretRef = {
                                namespace: "default"
                                name: "mysqlsecret"
                                key: "password"
                            }
                            networkRef = {
                                id: "platform-ref-azure-cluster"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-azure-cluster-db-conn-mysql"
                            namespace: "default"
                        }
                    }
                },

                # 3. App claim (Ghost blog application)
                platformv1alpha1.XApp{
                    metadata = {
                        name: "platform-ref-azure-cluster-ghost"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec = {
                        parameters = {
                            providerConfigName: "platform-ref-azure-cluster"
                            helm = {
                                wait: False
                            }
                            passwordSecretRef = {
                                namespace: "default"
                                name: "platform-ref-azure-cluster-db-conn-mysql"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-azure-cluster-app-conn"
                            namespace: "default"
                        }
                    }
                }
            ]
            extraResources: [
                # Database password secret
                {
                    apiVersion: "v1"
                    kind: "Secret"
                    metadata = {
                        name: "mysqlsecret"
                        namespace: "default"
                    }
                    type: "Opaque"
                    data: {
                        password: "dXBiMHVuZHIwY2s1ITMxMzM3"
                    }
                },
                # Upbound ProviderConfig for Azure resources
                azurev1beta1.ProviderConfig{
                    metadata.name = "default"
                    spec = {
                        credentials = {
                            source = "Upbound"
                        }
                        clientID = "bcf40abd-283c-494b-b186-03d6c864be51"
                        tenantID = "b9925bc4-8383-4c37-b9d2-fa456d1bb1c7"
                        subscriptionID = "038f2b7c-3265-43b8-8624-c9ad5da610a8"
                    }
                }
            ]
            skipDelete: False
            timeoutSeconds: 4500
        }
    }
]
items = _items
