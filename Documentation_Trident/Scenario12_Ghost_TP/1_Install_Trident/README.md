# Étape 1 : Installation de Trident

Cette section guide l'installation de Trident 25.10 avec Helm.

## Vue d'ensemble

Trident est le provisionneur de volumes CSI (Container Storage Interface) de NetApp. Il permet de provisionner dynamiquement des volumes de stockage persistants pour les applications Kubernetes.

## Prérequis

- Helm 3.x installé
- Cluster Kubernetes fonctionnel
- Accès administrateur au cluster
- Registry Docker privé (optionnel, pour les images)

## Installation

### Méthode 1 : Script automatique

```bash
cd 1_Install_Trident
./install_trident.sh
```

### Méthode 2 : Installation manuelle

#### 1. Créer le namespace

```bash
kubectl create namespace trident
```

#### 2. Créer le secret pour le registry (si registry privé)

```bash
kubectl create secret docker-registry regcred \
  --docker-username=registryuser \
  --docker-password=Netapp1! \
  -n trident \
  --docker-server=registry.demo.netapp.com
```

#### 3. Ajouter le repository Helm

```bash
helm repo add netapp-trident https://netapp.github.io/trident-helm-chart/
helm repo update netapp-trident
```

#### 4. Installer Trident

```bash
helm install trident netapp-trident/trident-operator \
  --version 100.2510.0 \
  --namespace trident \
  --set tridentAutosupportImage=registry.demo.netapp.com/trident-autosupport:25.10.0 \
  --set operatorImage=registry.demo.netapp.com/trident-operator:25.10.0 \
  --set tridentImage=registry.demo.netapp.com/trident:25.10.0 \
  --set tridentSilenceAutosupport=true \
  --set windows=true \
  --set imagePullSecrets[0]=regcred
```

**Note** : Si vous n'utilisez pas de registry privé, supprimez les paramètres `--set` liés aux images et au `imagePullSecrets`.

#### 5. Vérifier l'installation

Attendre quelques minutes que Trident soit déployé, puis vérifier :

```bash
# Vérifier les pods
kubectl get pods -n trident

# Vérifier la version
kubectl get torc trident -n trident

# Installer tridentctl (optionnel mais recommandé)
cd
mkdir -p 25.10.0 && cd 25.10.0
wget https://github.com/NetApp/trident/releases/download/v25.10.0/trident-installer-25.10.0.tar.gz
tar -xf trident-installer-25.10.0.tar.gz
rm -f /usr/local/bin/tridentctl
ln -sf /root/25.10.0/trident-installer/tridentctl /usr/local/bin/tridentctl

# Vérifier la version
tridentctl -n trident version
```

**Résultat attendu** :

```
+----------------+----------------+
| SERVER VERSION | CLIENT VERSION |
+----------------+----------------+
| 25.10.0        | 25.10.0        |
+----------------+----------------+
```

## Configuration du backend ONTAP

Si le backend ONTAP n'est pas encore configuré, vous devez le créer maintenant.

### 1. Créer le secret pour les credentials ONTAP

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: secret-nas-svm-creds
  namespace: trident
type: Opaque
stringData:
  username: vsadmin
  password: Netapp1!
EOF
```

**Note** : Adaptez les credentials selon votre environnement.

### 2. Créer le TridentBackendConfig

```bash
cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentBackendConfig
metadata:
  name: backend-tbc-nfs
  namespace: trident
spec:
  version: 1
  storageDriverName: ontap-nas
  managementLIF: 192.168.0.133
  dataLIF: 192.168.0.131
  backendName: BackendForNFS
  nasType: nfs
  autoExportCIDRs:
  - 192.168.0.0/24
  autoExportPolicy: true
  svm: nassvm
  defaults:
    snapshotDir: 'true'
  credentials:
    name: secret-nas-svm-creds
EOF
```

**Note** : Adaptez les adresses IP, le nom du SVM et le CIDR selon votre environnement.

### 3. Vérifier le backend

```bash
tridentctl -n trident get backend
```

**Résultat attendu** : Le backend doit être en état `online`.

## Création de la Storage Class

Si la Storage Class NFS n'existe pas encore, créez-la :

```bash
cat << EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: storage-class-nfs
provisioner: csi.trident.netapp.io
parameters:
  backendType: "ontap-nas"
  nasType: "nfs"
allowVolumeExpansion: true
EOF
```

### Vérifier la Storage Class

```bash
kubectl get storageclass storage-class-nfs
```

## Dépannage

### Les pods Trident ne démarrent pas

```bash
# Vérifier les logs
kubectl logs -n trident -l app=trident-operator

# Vérifier les événements
kubectl get events -n trident --sort-by='.lastTimestamp'
```

### Le backend n'est pas en ligne

```bash
# Vérifier la connectivité réseau
ping <management-lif-ip>

# Vérifier les credentials
tridentctl -n trident get backend -o json
```

## Prochaines étapes

Une fois Trident installé et le backend configuré, vous pouvez passer à l'étape suivante :

**[2_Install_TridentProtect](../2_Install_TridentProtect/)** - Installation de Trident Protect
