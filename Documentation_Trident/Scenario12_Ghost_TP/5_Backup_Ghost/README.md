# Étape 5 : Création de snapshots et backups

Cette section guide la création de snapshots et backups de l'application Ghost.

## Vue d'ensemble

Trident Protect permet de créer deux types de protection :

1. **Snapshot** : Capture instantanée des volumes et métadonnées (rapide, stocké sur ONTAP)
2. **Backup** : Copie complète des données vers l'AppVault (plus lent, permet la restauration cross-cluster)

## Prérequis

- Application Trident Protect créée et en état `Ready`
- AppVault disponible
- Application Ghost fonctionnelle avec du contenu

## Création d'un Snapshot

### Méthode 1 : Script automatique

```bash
cd 5_Backup_Ghost
./create_backup.sh
```

### Méthode 2 : Création manuelle

#### 1. Créer un snapshot

```bash
tridentctl-protect create snapshot ghost-snap1 \
  --app ghost-app \
  --appvault ontap-vault \
  -n ghost-tp
```

#### 2. Vérifier le snapshot

```bash
tridentctl-protect get snap -n ghost-tp
```

**Résultat attendu** :

```
+-------------+-----------+----------------+-----------+-------+-----+
|    NAME     |    APP    | RECLAIM POLICY |   STATE   | ERROR | AGE |
+-------------+-----------+----------------+-----------+-------+-----+
| ghost-snap1 | ghost-app | Delete         | Completed |       | XXs |
+-------------+-----------+----------------+-----------+-------+-----+
```

#### 3. Vérifier les Volume Snapshots créés

```bash
kubectl get volumesnapshot -n ghost-tp
```

Un Volume Snapshot est créé pour chaque PVC de l'application.

## Création d'un Backup

Un backup copie les données vers l'AppVault S3, permettant une restauration complète même si le cluster est perdu.

#### 1. Créer un backup depuis un snapshot

```bash
tridentctl-protect create backup ghost-backup1 \
  --app ghost-app \
  --snapshot ghost-snap1 \
  --appvault ontap-vault \
  -n ghost-tp
```

**Note** : Si vous ne spécifiez pas de snapshot, Trident Protect créera automatiquement un snapshot avant le backup.

#### 2. Vérifier le backup

```bash
tridentctl-protect get backup -n ghost-tp
```

**Résultat attendu** :

```
+---------------+-----------+----------------+-----------+-------+-------+
|     NAME      |    APP    | RECLAIM POLICY |   STATE   | ERROR |  AGE  |
+---------------+-----------+----------------+-----------+-------+-------+
| ghost-backup1 | ghost-app | Retain         | Completed |       | XXmXXs |
+---------------+-----------+----------------+-----------+-------+-------+
```

**Note** : Le backup prend plus de temps qu'un snapshot car il copie les données vers S3.

#### 3. Vérifier le contenu dans l'AppVault

```bash
# Lister le contenu de l'AppVault
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources all \
  --app ghost-app \
  -n trident-protect
```

## Planification automatique (Optionnel)

Vous pouvez créer un schedule pour automatiser les snapshots et backups :

```bash
cat << EOF | kubectl apply -f -
apiVersion: protect.trident.netapp.io/v1
kind: Schedule
metadata:
  name: ghost-schedule
  namespace: ghost-tp
spec:
  appVaultRef: ontap-vault
  applicationRef: ghost-app
  backupRetention: "7"
  dataMover: Kopia
  enabled: true
  granularity: Daily
  snapshotRetention: "3"
EOF
```

Cela créera :

- Un snapshot quotidien (conservé 3 jours)
- Un backup quotidien (conservé 7 jours)

## Dépannage

### Le snapshot n'est pas complété

```bash
# Vérifier les détails
kubectl describe snapshot ghost-snap1 -n ghost-tp

# Vérifier les Volume Snapshots
kubectl get volumesnapshot -n ghost-tp

# Vérifier les logs Trident Protect
kubectl logs -n trident-protect -l app=trident-protect-controller-manager --tail=50
```

### Le backup échoue

```bash
# Vérifier l'état du backup
kubectl describe backup ghost-backup1 -n ghost-tp

# Vérifier l'AppVault
tridentctl-protect get appvault ontap-vault -n trident-protect

# Vérifier les credentials S3
kubectl get secret s3-creds -n trident-protect
```

### Le backup prend trop de temps

C'est normal, surtout pour la première fois. Le backup copie toutes les données vers S3. Vous pouvez suivre la progression :

```bash
# Surveiller l'état
watch -n 5 'tridentctl-protect get backup ghost-backup1 -n ghost-tp'
```

## Prochaines étapes

Une fois le backup créé et complété, vous pouvez passer à l'étape suivante :

**[6_Destroy_Ghost](../6_Destroy_Ghost/)** - Destruction de l'application
