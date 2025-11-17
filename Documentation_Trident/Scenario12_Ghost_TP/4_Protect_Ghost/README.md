# Étape 4 : Activation de la protection Trident Protect sur Ghost

Cette section guide l'activation de Trident Protect pour protéger l'application Ghost.

## Vue d'ensemble

Trident Protect permet de protéger des applications Kubernetes complètes en créant des snapshots et backups. Pour cela, il faut d'abord créer une **Application** Trident Protect qui identifie les ressources à protéger.

## Prérequis

- Trident Protect installé et fonctionnel
- AppVault créé et disponible
- Application Ghost déployée et fonctionnelle
- Labels cohérents sur tous les objets (Deployment, PVC, Service)

## Création de l'Application Trident Protect

### Méthode 1 : Script automatique

```bash
cd 4_Protect_Ghost
./protect_ghost.sh
```

### Méthode 2 : Création manuelle

#### 1. Vérifier que l'AppVault existe

```bash
tridentctl-protect get appvault ontap-vault -n trident-protect
```

**Résultat attendu** : L'AppVault doit être en état `Available`.

#### 2. Vérifier les labels de l'application

Les labels sont importants pour que Trident Protect identifie les ressources à protéger :

```bash
kubectl get all,pvc -n ghost-tp --show-labels
```

Tous les objets doivent avoir le label `app.kubernetes.io/name=ghost-tp`.

#### 3. Créer l'Application Trident Protect

Il existe plusieurs façons de définir une application :

**Option A : Par namespace complet**

```bash
tridentctl-protect create app ghost-app --namespaces 'ghost-tp' -n ghost-tp
```

**Option B : Par labels (recommandé)**

```bash
tridentctl-protect create app ghost-app --namespaces 'ghost-tp(app.kubernetes.io/name=ghost-tp)' -n ghost-tp
```

Cette option protège uniquement les ressources avec le label `app.kubernetes.io/name=ghost-tp` dans le namespace `ghost-tp`.

#### 4. Vérifier l'Application

```bash
tridentctl-protect get app ghost-app -n ghost-tp
```

**Résultat attendu** :

```
+-----------+----------+-------+-----+
|   NAME    | NAMESPACES | STATE | AGE |
+-----------+----------+-------+-----+
| ghost-app | ghost-tp  | Ready | XXs |
+-----------+----------+-------+-----+
```

#### 5. Vérifier les ressources détectées

```bash
# Lister les ressources de l'application
kubectl get application ghost-app -n ghost-tp -o yaml
```

## Test : Créer un snapshot manuel

Pour tester que la protection fonctionne, créons un snapshot manuel :

```bash
tridentctl-protect create snapshot ghost-snap1 \
  --app ghost-app \
  --appvault ontap-vault \
  -n ghost-tp
```

Vérifier le snapshot :

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

## Dépannage

### L'Application n'est pas en état Ready

```bash
# Vérifier les détails
kubectl describe application ghost-app -n ghost-tp

# Vérifier les logs Trident Protect
kubectl logs -n trident-protect -l app=trident-protect-controller-manager --tail=50
```

### Les ressources ne sont pas détectées

```bash
# Vérifier que les labels sont corrects
kubectl get all,pvc -n ghost-tp --show-labels

# Vérifier la définition de l'application
kubectl get application ghost-app -n ghost-tp -o yaml
```

### L'AppVault n'est pas disponible

```bash
# Vérifier l'état de l'AppVault
tridentctl-protect get appvault ontap-vault -n trident-protect

# Vérifier les credentials S3
kubectl get secret s3-creds -n trident-protect
```

## Prochaines étapes

Une fois l'Application Trident Protect créée et vérifiée, vous pouvez passer à l'étape suivante :

**[5_Backup_Ghost](../5_Backup_Ghost/)** - Création de snapshots et backups
