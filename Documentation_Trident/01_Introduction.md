# À quoi sert Trident

## Vue d'ensemble

Trident (Astra Trident) est un provisionneur de volumes dynamique pour Kubernetes et OpenShift, développé par NetApp. Il agit comme un driver CSI (Container Storage Interface) qui permet de provisionner automatiquement des volumes de stockage persistants pour les applications conteneurisées.

## Rôle de Trident

Trident sert de pont entre Kubernetes/OpenShift et les systèmes de stockage NetApp (principalement ONTAP). Il permet de :

- **Provisionner dynamiquement** des volumes de stockage à la demande
- **Gérer le cycle de vie** des volumes (création, expansion, suppression)
- **Abstraire la complexité** du stockage pour les développeurs
- **Intégrer nativement** avec les fonctionnalités avancées d'ONTAP (snapshots, clones, QoS, etc.)

## Architecture

Trident s'installe dans un namespace dédié (généralement `trident`) et comprend :

- **Trident Controller** : Composant principal qui gère les opérations de stockage
- **Trident Node** : DaemonSet qui s'exécute sur chaque nœud du cluster pour gérer les montages
- **CSI Drivers** : Drivers spécifiques pour chaque type de backend (ONTAP-NAS, ONTAP-SAN, etc.)

## Protocoles supportés

Trident supporte plusieurs protocoles de stockage :

- **NFS** (Network File System) : Pour le stockage de fichiers avec accès partagé (RWX)
- **iSCSI** : Pour le stockage en bloc avec accès exclusif (RWO)
- **NVMe over TCP** : Protocole moderne pour le stockage en bloc haute performance
- **SMB** (Server Message Block) : Pour les environnements Windows

## Drivers ONTAP disponibles

Avec un backend ONTAP, Trident offre 5 drivers différents :

1. **ONTAP-NAS** : Stockage de fichiers haute performance, un volume ONTAP par PVC
2. **ONTAP-NAS-ECONOMY** : Stockage de fichiers économique, plusieurs PVC par volume ONTAP
3. **ONTAP-NAS-FLEXGROUP** : Pour des volumes NFS très volumineux (jusqu'à 20 PB)
4. **ONTAP-SAN** : Stockage en bloc haute performance, un LUN par PVC
5. **ONTAP-SAN-ECONOMY** : Stockage en bloc économique, plusieurs LUN par FlexVol (jusqu'à 50 LUN)

## Cas d'usage principaux

- **Applications stateful** nécessitant un stockage persistant
- **Bases de données** nécessitant des performances garanties
- **Applications partageant des données** entre plusieurs pods (RWX)
- **Environnements multi-tenant** avec isolation des données
- **Sauvegarde et restauration** d'applications (avec Trident Protect)

## Intégration avec Kubernetes

Trident s'intègre parfaitement avec les concepts Kubernetes :

- **Storage Classes** : Définissent les caractéristiques du stockage (performance, protocole, etc.)
- **PersistentVolumeClaims (PVC)** : Demandes de volumes par les applications
- **PersistentVolumes (PV)** : Volumes effectivement provisionnés
- **CSI Snapshots** : Snapshots natifs Kubernetes
- **Volume Expansion** : Extension dynamique des volumes

## Avantages clés

1. **Automatisation complète** : Plus besoin d'intervention manuelle pour créer des volumes
2. **Intégration native ONTAP** : Accès à toutes les fonctionnalités avancées d'ONTAP
3. **Multi-protocole** : Support de NFS, iSCSI, NVMe, SMB
4. **Haute disponibilité** : Intégration avec les fonctionnalités HA d'ONTAP
5. **Sécurité** : Support du chiffrement, CHAP, RBAC
6. **Performance** : QoS, multipathing, optimisation des performances

## Conclusion

Trident transforme le stockage en infrastructure as code, permettant aux équipes de développement de provisionner du stockage de manière aussi simple qu'ils provisionnent des pods, tout en bénéficiant de la puissance et de la fiabilité des systèmes de stockage NetApp ONTAP.
