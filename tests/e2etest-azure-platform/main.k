import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.platform.azure.v1alpha1 as platformazurev1alpha1
import models.io.upbound.platform.v1alpha1 as platformv1alpha1
import models.io.upbound.platformref.azure.v1alpha1 as platformrefazurev1alpha1
import models.io.upbound.azurem.v1beta1 as azuremv1beta1
import models.io.crossplane.pkg.v1 as pkgv1
import models.io.k8s.api.core.v1 as corev1

_items = [
    metav1alpha1.E2ETest{
        metadata.name: "azure-platform-e2e"
        spec = {
            crossplane = {
                version = "2.0.2-up.5"
                autoUpgrade = {
                    channel: "None"
                }
            }
            defaultConditions: ["Ready"]
            manifests: [
                # 1. Cluster claim (AKS + networking + observability + GitOps)
                platformrefazurev1alpha1.Cluster{
                    metadata = {
                        name: "platform-ref-azure-e2e"
                        namespace: "default"
                    }
                    spec = {
                        parameters = {
                            id: "platform-ref-azure-e2e"
                            region: "westeurope"
                            version: "1.34"
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
                    }
                },

                # 2. Database claim (MySQL)
                platformazurev1alpha1.SQLInstance{
                    metadata = {
                        name: "platform-ref-azure-cluster-db-mysql-e2e"
                        namespace: "default"
                    }
                    spec = {
                        crossplane = {
                            compositionSelector = {
                                matchLabels = {
                                    dbengine: "mysql"
                                }
                            }
                        }
                        parameters = {
                            region: "westeurope"
                            storageGB: 20  # Minimum 20 GB for MySQL
                            version: "10.3"
                            passwordSecretRef = {
                                name: "mysqlsecret"
                                key: "password"
                            }
                            networkRef = {
                                id: "platform-ref-azure-e2e"
                            }
                        }
                        writeConnectionSecretToRef = {
                            name: "platform-ref-azure-e2e-db-conn-mysql"
                        }
                    }
                },

                # 3. App claim (Ghost blog application)
                platformv1alpha1.App{
                    metadata = {
                        name: "platform-ref-azure-e2e-ghost"
                        namespace: "default"
                        labels = {
                            "platform.upbound.io/deletion-ordering": "enabled"
                        }
                    }
                    spec = {
                        parameters = {
                            helm = {
                                chart = {
                                    name: "ghost"
                                    repo: "oci://registry-1.docker.io/bitnamicharts"
                                    version: "25.0.4"
                                }
                                wait: False
                            }
                            providerConfigName: "platform-ref-azure-e2e"
                            passwordSecretRef = {
                                namespace: "default"
                                name: "platform-ref-azure-e2e-db-conn-mysql"
                            }
                        }
                    }
                }
            ]
            initResources: [
                # Provider family for Azure (workaround for ProviderConfig RBAC)
                pkgv1.Provider{
                    metadata = {
                        name: "upbound-provider-family-azure"
                    }
                    spec = {
                        package: "xpkg.upbound.io/upbound/provider-family-azure:v2.3.0"
                    }
                }
            ]
            extraResources: [
                # Database password secret
                corev1.Secret{
                    metadata = {
                        name: "mysqlsecret"
                        namespace: "default"
                    }
                    type: "Opaque"
                    data: {
                        password: "dXBiMHVuZHIwY2s1ITMxMzM3"
                    }
                },
                # Upbound ProviderConfig for Azure resources (namespaced v2)
                azuremv1beta1.ProviderConfig{
                    metadata = {
                        name = "default"
                        namespace = "default"
                    }
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
