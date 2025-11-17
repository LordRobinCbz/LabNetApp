# Use case de démonstration: Backup

## Vue d'ensemble

Trident Protect permet de sauvegarder des applications Kubernetes complètes, incluant leurs données persistantes et leurs métadonnées. Cette démonstration montre comment configurer et exécuter des sauvegardes.

## Prérequis

- Trident installé et fonctionnel
- Trident Protect installé dans le namespace `trident-protect`
- Un AppVault configuré (bucket S3)
- Une application avec des volumes persistants à sauvegarder

## Installation de Trident Protect

### 1. Créer le namespace

```bash
kubectl create ns trident-protect
```

### 2. Créer le secret pour le registry (si registry privé)

```bash
kubectl create secret docker-registry regcred \
  --docker-username=registryuser \
  --docker-password=Netapp1! \
  -n trident-protect \
  --docker-server=registry.demo.netapp.com
```

### 3. Installer avec Helm

```bash
# Ajouter le repository
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/

# Installer Trident Protect
helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod1 \
  --version 100.2510.0 \
  --namespace trident-protect \
  -f trident_protect_helm_values.yaml
```

### 4. Installer le CLI

```bash
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.10.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin
```

## Configuration d'un AppVault

Un AppVault est un dépôt de sauvegarde (généralement un bucket S3) où Trident Protect stocke les métadonnées et les données des applications.

### 1. Créer un secret pour les credentials S3

```bash
kubectl create secret generic s3-creds \
  --from-literal=accessKeyID=<access-key> \
  --from-literal=secretAccessKey=<secret-key> \
  -n trident-protect
```

### 2. Créer l'AppVault

```bash
tridentctl-protect create appvault ontap-vault \
  -s s3-creds \
  --bucket s3lod \
  --endpoint 192.168.0.230 \
  --skip-cert-validation \
  --no-tls \
  -n trident-protect
```

### 3. Vérifier l'AppVault

```bash
tridentctl-protect get appvault ontap-vault -n trident-protect
```

## Déploiement d'une application de test

### 1. Créer un namespace pour l'application

```bash
kubectl create ns tpsc05busybox
```

### 2. Déployer l'application avec volumes persistants

```yaml
# busybox.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mydata1
  namespace: tpsc05busybox
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: storage-class-nfs
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mydata2
  namespace: tpsc05busybox
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: storage-class-nfs
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox
  namespace: tpsc05busybox
  labels:
    app: busybox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
    spec:
      containers:
        - name: busybox
          image: busybox:latest
          command: ["sleep", "3600"]
          volumeMounts:
            - name: data1
              mountPath: /data1
            - name: data2
              mountPath: /data2
      volumes:
        - name: data1
          persistentVolumeClaim:
            claimName: mydata1
        - name: data2
          persistentVolumeClaim:
            claimName: mydata2
```

```bash
kubectl create -f busybox.yaml
```

### 3. Écrire des données de test

```bash
# Écrire des données dans les volumes
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- \
  sh -c 'echo "bbox test1 in folder data1!" > /data1/file.txt'

kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- \
  sh -c 'echo "bbox test1 in folder data2!" > /data2/file.txt'

# Vérifier les données
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- \
  cat /data1/file.txt
```

## Création d'une application Trident Protect

### 1. Définir l'application

Une application peut être définie de plusieurs façons :

- Par namespace complet
- Par labels dans un namespace
- Par plusieurs namespaces

```bash
# Exemple : Application basée sur des labels
tridentctl-protect create app bbox \
  --namespaces 'tpsc05busybox(app=busybox)' \
  -n tpsc05busybox
```

### 2. Vérifier l'application

```bash
tridentctl-protect get app -n tpsc05busybox
```

## Création d'un snapshot

Un snapshot capture l'état d'une application à un instant T, incluant les snapshots des volumes et les métadonnées.

### 1. Créer un snapshot manuel

```bash
tridentctl-protect create snapshot bboxsnap1 \
  --app bbox \
  --appvault ontap-vault \
  -n tpsc05busybox
```

### 2. Vérifier le statut

```bash
tridentctl-protect get snap -n tpsc05busybox
```

### 3. Vérifier les VolumeSnapshots créés

```bash
kubectl get volumesnapshot -n tpsc05busybox
```

## Création d'un backup

Un backup copie les données des volumes vers l'AppVault en plus des métadonnées.

### 1. Créer un backup

```bash
tridentctl-protect create backup bboxbkp1 \
  --app bbox \
  --snapshot bboxsnap1 \
  --appvault ontap-vault \
  -n tpsc05busybox
```

### 2. Vérifier le statut

```bash
tridentctl-protect get backup -n tpsc05busybox
```

Le backup prend plus de temps qu'un snapshot car il copie les données vers le bucket S3.

### 3. Vérifier le contenu du bucket

```bash
# Récupérer le chemin du snapshot
SNAPPATH=$(kubectl get snapshot bboxsnap1 -n tpsc05busybox -o=jsonpath='{.status.appArchivePath}')

# Lister le contenu
aws s3 ls --no-verify-ssl --endpoint-url http://192.168.0.230 s3://s3lod/$SNAPPATH --recursive
```

Vous devriez voir :

- `application.json` : Métadonnées de l'application
- `resource_backup.tar.gz` : Archive des ressources Kubernetes
- `volume_snapshots.json` : Informations sur les snapshots de volumes
- Dossier `kopia/` : Données des volumes (pour les backups)

## Planification automatique

### Créer un schedule

Pour automatiser les snapshots et backups :

```yaml
# schedule.yaml
apiVersion: protect.trident.netapp.io/v1
kind: Schedule
metadata:
  name: bbox-sched1
  namespace: tpsc05busybox
spec:
  appVaultRef: ontap-vault
  applicationRef: bbox
  backupRetention: "3"
  dataMover: Kopia
  enabled: true
  granularity: Custom
  recurrenceRule: |-
    DTSTART:20250106T000100Z
    RRULE:FREQ=MINUTELY;INTERVAL=5
  snapshotRetention: "3"
```

```bash
kubectl apply -f schedule.yaml
```

### Vérifier le schedule

```bash
tridentctl-protect get schedule -n tpsc05busybox
```

Le schedule créera automatiquement des snapshots et backups selon la règle définie.

## Utilisation de hooks

Les hooks permettent d'interagir avec l'application avant/après les opérations de protection.

### Types de hooks

- **Pre-snapshot** : Exécuté avant la création d'un snapshot
- **Post-snapshot** : Exécuté après la création d'un snapshot
- **Pre-backup** : Exécuté avant la création d'un backup
- **Post-backup** : Exécuté après la création d'un backup

### Exemple avec un hook

Voir le [Scenario06](../../Kubernetes_v6/Trident_Protect_Scenarios/Scenario06) pour des exemples détaillés d'utilisation de hooks.

## Vérification et monitoring

### Lister tous les snapshots et backups

```bash
# Snapshots
tridentctl-protect get snap -n tpsc05busybox

# Backups
tridentctl-protect get backup -n tpsc05busybox
```

### Contenu de l'AppVault

```bash
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources all \
  --app bbox \
  -n trident-protect
```

### Logs de Trident Protect

```bash
kubectl logs -n trident-protect -l app=trident-protect-controller-manager
```

## Bonnes pratiques

1. **Fréquence des snapshots** : Plus fréquents que les backups (snapshots rapides, backups plus lents)
2. **Rétention** : Configurez une politique de rétention appropriée
3. **Hooks** : Utilisez des hooks pour les applications critiques (bases de données)
4. **Test de restauration** : Testez régulièrement la restauration des backups
5. **Monitoring** : Surveillez les échecs de backup et configurez des alertes

## Prochaines étapes

- [07_UseCase_Restore.md](07_UseCase_Restore.md) : Comment restaurer des applications depuis des backups
