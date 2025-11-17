# Étape 6 : Destruction de l'application

Cette section guide la destruction complète de l'application Ghost pour simuler une perte de données.

## Vue d'ensemble

Pour démontrer la capacité de restauration de Trident Protect, nous allons supprimer complètement l'application Ghost, incluant :

- Le Deployment
- Les PVC (volumes persistants)
- Le Service
- Optionnellement le namespace

## ⚠️ Attention

Cette opération est **destructive** et supprimera toutes les données de l'application. Assurez-vous d'avoir créé un backup avant de procéder.

## Destruction

### Méthode 1 : Script automatique

```bash
cd 6_Destroy_Ghost
./destroy_ghost.sh
```

### Méthode 2 : Destruction manuelle

#### Option A : Supprimer les ressources individuellement

```bash
# 1. Supprimer le Deployment
kubectl delete deployment blog -n ghost-tp

# 2. Supprimer le Service
kubectl delete service blog -n ghost-tp

# 3. Supprimer les PVC (⚠️ cela supprime aussi les données)
kubectl delete pvc blog-content -n ghost-tp

# 4. Vérifier que tout est supprimé
kubectl get all,pvc -n ghost-tp
```

#### Option B : Supprimer le namespace complet

```bash
# Supprimer le namespace (supprime tout ce qu'il contient)
kubectl delete namespace ghost-tp

# Vérifier que le namespace est supprimé
kubectl get namespace ghost-tp
```

**Note** : Cette méthode supprime également l'Application Trident Protect. Vous devrez la recréer avant de restaurer.

## Vérification de la destruction

### Vérifier que les ressources sont supprimées

```bash
# Vérifier les ressources dans le namespace
kubectl get all,pvc -n ghost-tp

# Résultat attendu : No resources found (ou namespace n'existe plus)
```

### Vérifier que les volumes sont supprimés

```bash
# Vérifier les volumes Trident
tridentctl -n trident get volumes | grep ghost

# Les volumes doivent être supprimés (ou en cours de suppression)
```

### Vérifier que l'application n'est plus accessible

```bash
# Tester l'accès (doit échouer)
curl http://<node-ip>:30080

# Résultat attendu : Connection refused ou timeout
```

## Conservation du backup

**Important** : Même si l'application est supprimée, le backup reste disponible dans l'AppVault :

```bash
# Lister les backups disponibles
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --app ghost-app \
  -n trident-protect
```

Le backup est conservé et peut être utilisé pour restaurer l'application.

## Dépannage

### Le namespace ne se supprime pas

```bash
# Vérifier les ressources restantes
kubectl get all -n ghost-tp

# Vérifier les finalizers
kubectl get namespace ghost-tp -o yaml | grep finalizers

# Forcer la suppression (si nécessaire)
kubectl patch namespace ghost-tp -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Les PVC ne se suppriment pas

```bash
# Vérifier les finalizers
kubectl get pvc blog-content -n ghost-tp -o yaml | grep finalizers

# Vérifier les événements
kubectl describe pvc blog-content -n ghost-tp
```

## Prochaines étapes

Une fois l'application complètement supprimée, vous pouvez passer à l'étape suivante :

**[7_Restore_Ghost](../7_Restore_Ghost/)** - Restauration depuis backup
