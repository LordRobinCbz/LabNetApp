# Étape 2 : Installation de Trident Protect

Cette section guide l'installation de Trident Protect avec Helm.

## Vue d'ensemble

Trident Protect est une extension de Trident qui permet de sauvegarder, restaurer et protéger des applications Kubernetes complètes, incluant leurs données persistantes et leurs métadonnées.

## Prérequis

- Trident 24.02+ installé (recommandé 25.10+)
- Helm 3.x installé
- Registry Docker privé (optionnel, pour les images)
- Bucket S3 pour AppVault (sera créé dans cette étape)

## Installation

### Méthode 1 : Script automatique

```bash
cd 2_Install_TridentProtect
./install_trident_protect.sh
```

### Méthode 2 : Installation manuelle

#### 1. Créer le namespace

```bash
kubectl create namespace trident-protect
```

#### 2. Créer le secret pour le registry

```bash
kubectl create secret docker-registry regcred \
  --docker-username=registryuser \
  --docker-password=Netapp1! \
  -n trident-protect \
  --docker-server=registry.demo.netapp.com
```

#### 3. Ajouter le repository Helm

```bash
helm repo add netapp-trident-protect https://netapp.github.io/trident-protect-helm-chart/
helm registry login registry.demo.netapp.com -u registryuser -p Netapp1!
```

#### 4. Installer Trident Protect

```bash
helm install trident-protect netapp-trident-protect/trident-protect \
  --set clusterName=lod1 \
  --version 100.2510.0 \
  --namespace trident-protect \
  -f trident_protect_helm_values.yaml
```

**Note** : Le fichier `trident_protect_helm_values.yaml` contient la configuration pour utiliser le registry privé.

#### 5. Vérifier l'installation

Attendre quelques secondes que Trident Protect soit déployé :

```bash
# Vérifier les pods
kubectl get pods -n trident-protect

# Résultat attendu :
# NAME                                                      READY   STATUS    RESTARTS   AGE
# trident-protect-controller-manager-xxxxx-xxxxx           1/1     Running   0          XXs
```

#### 6. Installer le CLI tridentctl-protect

```bash
cd
curl -L -o tridentctl-protect https://github.com/NetApp/tridentctl-protect/releases/download/25.10.0/tridentctl-protect-linux-amd64
chmod +x tridentctl-protect
mv ./tridentctl-protect /usr/local/bin

# Vérifier l'installation
tridentctl-protect version
```

**Résultat attendu** : `25.10.0`

## Création de l'AppVault

L'AppVault est un dépôt de sauvegarde (bucket S3) où Trident Protect stocke les métadonnées et les données des applications.

### 1. Récupérer les credentials S3

Vous devez avoir :

- L'access key S3
- Le secret key S3
- L'endpoint S3 (ex: `192.168.0.230`)
- Le nom du bucket (ex: `s3lod`)

Si vous ne les avez pas, consultez la documentation de création du bucket S3 dans `Kubernetes_v6/Trident_Protect_Scenarios/Scenario01/README.md`.

### 2. Créer le secret pour les credentials S3

```bash
kubectl create secret generic s3-creds \
  --from-literal=accessKeyID=<access-key> \
  --from-literal=secretAccessKey=<secret-key> \
  -n trident-protect
```

**Exemple** :

```bash
kubectl create secret generic s3-creds \
  --from-literal=accessKeyID=EO1XP61T31I8EDGUZ1PM \
  --from-literal=secretAccessKey=SthzvJ1S_QY4N3ng_r5n2L8hPA4tdCVtPc6D14gx \
  -n trident-protect
```

### 3. Créer l'AppVault

```bash
tridentctl-protect create appvault ontap-vault \
  -s s3-creds \
  --bucket s3lod \
  --endpoint 192.168.0.230 \
  --skip-cert-validation \
  --no-tls \
  -n trident-protect
```

**Note** : Adaptez le nom du bucket, l'endpoint et les options selon votre environnement.

### 4. Vérifier l'AppVault

```bash
tridentctl-protect get appvault ontap-vault -n trident-protect
```

**Résultat attendu** :

```
+-------------+----------+-----------+-------+---------+------+
|    NAME     | PROVIDER |   STATE   | ERROR | MESSAGE | AGE  |
+-------------+----------+-----------+-------+---------+------+
| ontap-vault | OntapS3  | Available |       |         | XXs  |
+-------------+----------+-----------+-------+---------+------+
```

## Dépannage

### Les pods Trident Protect ne démarrent pas

```bash
# Vérifier les logs
kubectl logs -n trident-protect -l app=trident-protect-controller-manager

# Vérifier les événements
kubectl get events -n trident-protect --sort-by='.lastTimestamp'
```

### L'AppVault n'est pas disponible

```bash
# Vérifier la connectivité S3
curl -v http://<endpoint>:<port>

# Vérifier les credentials
kubectl get secret s3-creds -n trident-protect -o yaml
```

## Prochaines étapes

Une fois Trident Protect installé et l'AppVault créé, vous pouvez passer à l'étape suivante :

**[3_Deploy_Ghost](../3_Deploy_Ghost/)** - Déploiement de l'application Ghost
