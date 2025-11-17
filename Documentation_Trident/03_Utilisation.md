# Comment s'en servir

## Vue d'ensemble

Une fois Trident installé, l'utilisation se fait en deux étapes principales :

1. **Configuration par l'administrateur** : Création des backends et Storage Classes
2. **Utilisation par les développeurs** : Création de PVC pour les applications

## Configuration des backends

### Qu'est-ce qu'un backend ?

Un backend est la configuration qui permet à Trident de se connecter à un système de stockage (ONTAP). Il contient :

- Le type de driver (ONTAP-NAS, ONTAP-SAN, etc.)
- Les informations de connexion (IP, credentials)
- Les paramètres par défaut (agrégats, SVM, etc.)

### Méthode 1 : Avec TridentBackendConfig (Recommandé)

Depuis Trident 21.04, la méthode recommandée utilise des CRD Kubernetes.

#### Créer un secret pour les credentials

```bash
cat << EOF | kubectl create -f -
apiVersion: v1
kind: Secret
metadata:
  name: ontap-nas-secret
  namespace: trident
type: Opaque
stringData:
  username: admin
  password: Netapp1!
EOF
```

#### Créer le TridentBackendConfig

```bash
cat << EOF | kubectl create -f -
apiVersion: trident.netapp.io/v1
kind: TridentBackendConfig
metadata:
  name: backend-ontap-nas
  namespace: trident
spec:
  version: 1
  backendName: BackendForNFS
  storageDriverName: ontap-nas
  managementLIF: 192.168.0.101
  dataLIF: 192.168.0.131
  svm: nassvm
  credentials:
    name: ontap-nas-secret
  defaults:
    size: 20Gi
    snapshotPolicy: default
    snapshotReserve: "10"
    spaceReserve: volume
    splitOnClone: "false"
    encryption: "false"
EOF
```

#### Vérifier le backend

```bash
# Vérifier le statut
kubectl get tbc -n trident

# Vérifier avec tridentctl
tridentctl -n trident get backend
```

### Méthode 2 : Avec tridentctl (Legacy)

```bash
# Créer un fichier de configuration backend
cat > backend-nas.json << EOF
{
  "version": 1,
  "storageDriverName": "ontap-nas",
  "managementLIF": "192.168.0.101",
  "dataLIF": "192.168.0.131",
  "svm": "nassvm",
  "username": "admin",
  "password": "Netapp1!",
  "defaults": {
    "size": "20Gi"
  }
}
EOF

# Créer le backend
tridentctl -n trident create backend -f backend-nas.json
```

### Types de backends ONTAP

#### ONTAP-NAS (File Storage)

Pour le stockage de fichiers avec NFS ou SMB :

```yaml
storageDriverName: ontap-nas
# ou
storageDriverName: ontap-nas-economy  # Plus économique, plusieurs PVC par volume
# ou
storageDriverName: ontap-nas-flexgroup  # Pour volumes très volumineux
```

#### ONTAP-SAN (Block Storage)

Pour le stockage en bloc avec iSCSI ou NVMe :

```yaml
storageDriverName: ontap-san
# ou
storageDriverName: ontap-san-economy  # Plus économique, plusieurs LUN par FlexVol
```

## Création de Storage Classes

Les Storage Classes définissent les caractéristiques du stockage disponible pour les applications.

### Exemple : Storage Class NFS

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-nfs
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  media: "ssd"
  provisioningType: "thin"
  snapshots: "true"
allowVolumeExpansion: true
volumeBindingMode: Immediate
reclaimPolicy: Delete
```

### Exemple : Storage Class iSCSI avec LUKS

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-iscsi-luks
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-san"
  media: "ssd"
  provisioningType: "thin"
  luksEncryption: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

### Paramètres importants

- **backendType** : Type de backend (ontap-nas, ontap-san, etc.)
- **media** : Type de média (ssd, hdd, hybrid)
- **provisioningType** : thin ou thick
- **snapshots** : true pour activer les snapshots
- **allowVolumeExpansion** : true pour permettre l'expansion
- **volumeBindingMode** : Immediate ou WaitForFirstConsumer

## Utilisation par les développeurs

### Créer un PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: my-app
spec:
  accessModes:
    - ReadWriteOnce # ou ReadWriteMany pour NFS
  storageClassName: storage-class-nfs
  resources:
    requests:
      storage: 10Gi
```

### Utiliser le PVC dans un Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: my-app
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-pvc
```

### Commandes utiles

```bash
# Lister les PVC
kubectl get pvc

# Détails d'un PVC
kubectl describe pvc my-pvc

# Lister les volumes Trident
tridentctl -n trident get volume

# Détails d'un volume
tridentctl -n trident get volume <volume-name>
```

## Bonnes pratiques

### 1. Organisation par namespace

Créez des namespaces dédiés pour chaque application :

```bash
kubectl create namespace my-app
```

### 2. Gestion des credentials

- Utilisez des secrets Kubernetes pour stocker les credentials
- Ne jamais hardcoder les mots de passe dans les fichiers YAML
- Utilisez des utilisateurs ONTAP dédiés avec des permissions minimales

### 3. Sécurité

- Activez CHAP pour iSCSI
- Utilisez LUKS pour le chiffrement des volumes
- Configurez des export policies restrictives
- Désactivez showmount sur ONTAP

### 4. Performance

- Choisissez le bon driver selon vos besoins (NAS vs SAN, Economy vs Standard)
- Configurez QoS si nécessaire
- Utilisez des agrégats SSD pour les workloads critiques

### 5. Consommation

- Définissez des quotas au niveau Kubernetes, Trident ou ONTAP
- Surveillez la consommation avec Prometheus/Grafana
- Nettoyez régulièrement les volumes non utilisés

## Gestion des backends

### Lister les backends

```bash
# Avec kubectl
kubectl get tbc -n trident

# Avec tridentctl
tridentctl -n trident get backend
```

### Mettre à jour un backend

Modifiez le TridentBackendConfig :

```bash
kubectl edit tbc backend-ontap-nas -n trident
```

### Supprimer un backend

```bash
# Attention : assurez-vous qu'aucun volume n'utilise ce backend
kubectl delete tbc backend-ontap-nas -n trident
```

## Dépannage

### PVC en état Pending

```bash
# Vérifier les événements
kubectl describe pvc my-pvc

# Vérifier les logs Trident
kubectl logs -n trident -l app=trident-controller
```

### Problèmes de montage

```bash
# Vérifier les pods Trident Node
kubectl get pods -n trident -l app=trident-node

# Vérifier les logs
kubectl logs -n trident <trident-node-pod>
```

## Prochaines étapes

- [04_Fonctionnement.md](04_Fonctionnement.md) : Comprendre comment Trident fonctionne en interne
- [05_Commandes.md](05_Commandes.md) : Commandes essentielles
- [06_UseCase_Backup.md](06_UseCase_Backup.md) : Utiliser Trident Protect pour les sauvegardes
