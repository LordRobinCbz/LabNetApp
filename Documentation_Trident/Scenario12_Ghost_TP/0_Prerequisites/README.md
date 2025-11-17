# Étape 0 : Prérequis

Cette section vérifie que tous les prérequis sont en place avant de commencer le TP.

## Vérifications requises

### 1. Cluster Kubernetes

Vérifier que le cluster Kubernetes est accessible et fonctionnel :

```bash
kubectl cluster-info
kubectl get nodes
```

**Résultat attendu** : Tous les nœuds doivent être en état `Ready`.

### 2. Helm installé

Vérifier que Helm est installé :

```bash
helm version
```

**Résultat attendu** : Version Helm 3.x

### 3. Accès au backend ONTAP

Vérifier que vous avez :

- L'adresse IP du management LIF ONTAP
- L'adresse IP du data LIF ONTAP
- Le nom du SVM
- Les credentials (username/password) avec les droits `vsadmin`

**Exemple de configuration** :

- Management LIF : `192.168.0.133`
- Data LIF : `192.168.0.131`
- SVM : `nassvm`
- Username : `vsadmin`
- Password : `Netapp1!`

### 4. Registry Docker (optionnel)

Si vous utilisez un registry privé, vérifier que vous avez :

- L'URL du registry (ex: `registry.demo.netapp.com`)
- Les credentials (username/password)

### 5. Bucket S3 pour AppVault

Pour Trident Protect, vous aurez besoin d'un bucket S3. Vérifier que vous avez :

- L'endpoint S3 (ex: `192.168.0.230`)
- Le nom du bucket (ex: `s3lod`)
- Les credentials S3 (access key / secret key)

### 6. Espace disque

Vérifier l'espace disponible sur les nœuds :

```bash
kubectl top nodes
```

## Script de vérification

Un script est fourni pour automatiser ces vérifications :

```bash
cd 0_Prerequisites
./check_prerequisites.sh
```

## Prochaines étapes

Une fois tous les prérequis validés, vous pouvez passer à l'étape suivante :

**[1_Install_Trident](../1_Install_Trident/)** - Installation de Trident
