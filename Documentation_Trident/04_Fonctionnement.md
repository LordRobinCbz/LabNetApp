# Comment ça marche

## Architecture interne

### Composants principaux

Trident est composé de plusieurs composants qui travaillent ensemble :

#### 1. Trident Controller

Le contrôleur est le cerveau de Trident. Il :

- Écoute les événements Kubernetes (création de PVC, etc.)
- Gère le cycle de vie des volumes
- Communique avec les backends de stockage
- Maintient l'état dans une base de données (actuellement etcd ou CRD)

#### 2. Trident Node (DaemonSet)

Un DaemonSet s'exécute sur chaque nœud du cluster et :

- Gère les opérations de montage/démontage
- Implémente l'interface CSI Node
- Communique avec kubelet pour monter les volumes

#### 3. CSI Sidecars

Trident utilise plusieurs sidecars CSI standards :

- **external-provisioner** : Gère le provisionnement des volumes
- **external-attacher** : Gère l'attachement des volumes
- **external-resizer** : Gère l'expansion des volumes
- **external-snapshotter** : Gère les snapshots CSI

## Flux de provisionnement

### 1. Création d'un PVC

Quand un développeur crée un PersistentVolumeClaim :

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  storageClassName: storage-class-nas
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
```

### 2. Traitement par Trident

1. **Détection** : Le external-provisioner détecte le nouveau PVC
2. **Sélection du backend** : Trident sélectionne un backend compatible avec la Storage Class
3. **Création du volume** : Trident appelle l'API ONTAP pour créer le volume
4. **Création du PV** : Trident crée un PersistentVolume Kubernetes
5. **Binding** : Kubernetes lie le PVC au PV

### 3. Montage dans un Pod

Quand un Pod utilise le PVC :

1. **Attachement** : Le external-attacher attache le volume au nœud
2. **Montage** : Le Trident Node monte le volume (NFS mount ou iSCSI attach)
3. **Mapping** : Le volume est mappé dans le conteneur

## Intégration CSI

Trident implémente l'interface CSI (Container Storage Interface) standard :

### Interfaces CSI implémentées

- **Identity Service** : Informations sur le driver
- **Controller Service** : Opérations de contrôle (create, delete, snapshot)
- **Node Service** : Opérations sur les nœuds (mount, unmount)

### Opérations supportées

#### CreateVolume

Crée un volume sur le backend de stockage.

#### DeleteVolume

Supprime un volume du backend.

#### ControllerPublishVolume

Attache un volume à un nœud (pour iSCSI/NVMe).

#### ControllerUnpublishVolume

Détache un volume d'un nœud.

#### NodeStageVolume

Prépare le volume sur le nœud (formatage, etc.).

#### NodePublishVolume

Monte le volume dans le conteneur.

#### CreateSnapshot

Crée un snapshot d'un volume.

#### DeleteSnapshot

Supprime un snapshot.

#### ExpandVolume

Étend la taille d'un volume.

## Gestion des backends

### Découverte des backends

Trident maintient une liste de backends configurés. Pour chaque PVC :

1. Analyse de la Storage Class
2. Filtrage des backends compatibles
3. Sélection selon les critères (filters, selectors, topology)
4. Création du volume sur le backend sélectionné

### Virtual Storage Pools

Trident peut grouper plusieurs backends en pools virtuels pour :

- Répartir la charge
- Fournir de la redondance
- Gérer différents niveaux de service

## Gestion des volumes

### Cycle de vie d'un volume

1. **Provisioning** : Création du volume sur ONTAP
2. **Binding** : Association PVC ↔ PV
3. **Attach/Mount** : Montage dans un Pod
4. **In-use** : Volume utilisé par l'application
5. **Unmount/Detach** : Libération du volume
6. **Deletion** : Suppression (selon reclaimPolicy)

### Reclaim Policies

- **Delete** : Le volume est supprimé automatiquement quand le PVC est supprimé
- **Retain** : Le volume est conservé même après suppression du PVC

## Snapshots

### Snapshots CSI

Trident supporte les snapshots CSI natifs Kubernetes :

1. Création d'un VolumeSnapshot
2. Trident crée un snapshot ONTAP
3. Le snapshot peut être utilisé pour créer un nouveau PVC

### Snapshots ONTAP

Trident peut aussi exposer les snapshots ONTAP existants via le dossier `.snapshot` (si activé).

## Expansion de volumes

### Processus d'expansion

1. Modification du PVC (augmentation de la taille)
2. Trident détecte le changement
3. Expansion du volume sur ONTAP
4. Expansion du système de fichiers (si supporté)

### Limitations

- NFS : Supporté depuis Kubernetes 1.11
- iSCSI : Supporté depuis Kubernetes 1.16 (CSI)
- L'expansion ne peut que grandir, jamais rétrécir

## Import de volumes

Trident permet d'importer des volumes ONTAP existants :

1. Identification du volume ONTAP
2. Création d'un PV correspondant
3. Association avec un PVC

Utile pour :

- Migration de données
- Intégration de volumes pré-existants
- Disaster Recovery

## Topology Awareness

### CSI Topology

Trident supporte la topologie CSI pour :

- Placer les volumes près des pods qui les utilisent
- Respecter les contraintes de localisation
- Optimiser les performances

### Configuration

Les nœuds doivent être labellisés :

```bash
kubectl label node node1 topology.kubernetes.io/region=west
kubectl label node node1 topology.kubernetes.io/zone=zone1
```

## Performance et QoS

### QoS Policy Groups

Trident peut appliquer des QoS Policy Groups ONTAP :

- **Fixed QoS** : Limites fixes (IOPS, bande passante)
- **Adaptive QoS** : Limites basées sur la capacité

### Multipathing

Pour iSCSI, Trident configure automatiquement le multipathing pour :

- Haute disponibilité
- Performance améliorée
- Répartition de charge

## Sécurité

### Authentification

- **NAS** : Export policies, RBAC Kubernetes
- **SAN** : CHAP bidirectionnel, RBAC Kubernetes

### Chiffrement

- **LUKS** : Chiffrement au niveau du nœud pour iSCSI/NVMe
- **ONTAP NVE/NAE** : Chiffrement au niveau ONTAP

## Monitoring et logs

### Métriques

Trident expose des métriques Prometheus :

- Nombre de volumes
- Opérations réussies/échouées
- Latence des opérations
- Utilisation des backends

### Logs

Les logs sont disponibles via :

```bash
kubectl logs -n trident -l app=trident-controller
kubectl logs -n trident -l app=trident-node
```

## État et persistance

### Stockage de l'état

Trident stocke son état dans :

- **CRD** (Custom Resource Definitions) : Méthode moderne
- **etcd** : Méthode legacy (dépréciée)

### Synchronisation

Trident synchronise régulièrement son état avec :

- Les volumes Kubernetes (PV/PVC)
- Les volumes ONTAP
- Les backends configurés

## Conclusion

Trident fonctionne comme une couche d'abstraction intelligente entre Kubernetes et ONTAP, automatisant toutes les opérations de stockage tout en exposant les fonctionnalités avancées d'ONTAP aux applications Kubernetes.
