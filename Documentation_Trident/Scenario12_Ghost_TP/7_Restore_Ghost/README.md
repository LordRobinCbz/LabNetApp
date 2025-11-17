# Étape 7 : Restauration de l'application depuis backup

Cette section guide la restauration complète de l'application Ghost depuis un backup Trident Protect.

## Vue d'ensemble

Trident Protect permet de restaurer une application complète depuis un backup, incluant :

- Les ressources Kubernetes (Deployment, Service, PVC)
- Les données persistantes
- Les métadonnées de l'application

## Prérequis

- Backup disponible dans l'AppVault
- Namespace `ghost-tp` (sera créé si nécessaire)
- Storage Class `storage-class-nfs` disponible

## Restauration

### Méthode 1 : Script automatique

```bash
cd 7_Restore_Ghost
./restore_ghost.sh
```

### Méthode 2 : Restauration manuelle

#### 1. Lister les backups disponibles

```bash
# Lister les backups dans l'AppVault
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --app ghost-app \
  -n trident-protect
```

**Note** : Si le namespace `ghost-tp` a été supprimé, vous pouvez toujours lister les backups depuis le namespace `trident-protect`.

#### 2. Obtenir le chemin du backup

```bash
# Lister les backups avec leurs chemins
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --show-paths \
  --app ghost-app \
  -n trident-protect
```

Notez le chemin du backup que vous souhaitez restaurer (ex: `ghost-app_xxxxx/backups/ghost-backup1_xxxxx`).

#### 3. Créer le namespace si nécessaire

```bash
# Si le namespace a été supprimé, recréer-le
kubectl create namespace ghost-tp
```

#### 4. Restaurer depuis le backup (In-Place Restore)

```bash
tridentctl-protect create bir ghost-restore1 \
  --backup ghost-tp/ghost-backup1 \
  --appvault ontap-vault \
  -n ghost-tp \
  --dry-run | kubectl apply -f -
```

**Note** : L'option `--dry-run` génère le YAML sans l'appliquer. Supprimez-la pour appliquer directement.

#### 5. Vérifier la restauration

```bash
# Vérifier l'état de la restauration
tridentctl-protect get bir -n ghost-tp

# Résultat attendu :
# +----------------+-------------+-----------+-------+------+
# |      NAME      |   APPVAULT  |   STATE   | ERROR | AGE  |
# +----------------+-------------+-----------+-------+------+
# | ghost-restore1 | ontap-vault | Completed |       | XXs  |
# +----------------+-------------+-----------+-------+------+
```

#### 6. Vérifier que l'application est restaurée

```bash
# Vérifier les ressources
kubectl get all,pvc -n ghost-tp

# Vérifier que le pod est prêt
kubectl get pods -n ghost-tp

# Vérifier que le PVC est lié
kubectl get pvc -n ghost-tp
```

#### 7. Vérifier les données

```bash
# Vérifier que le volume est monté
kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -o name) -- \
  df -h /var/lib/ghost/content

# Vérifier le contenu
kubectl exec -n ghost-tp $(kubectl get pod -n ghost-tp -o name) -- \
  ls -la /var/lib/ghost/content
```

#### 8. Accéder à l'application

Une fois le pod en état `Running`, accédez à Ghost :

```
http://<node-ip>:30080
```

**Vérification** : Le contenu créé avant la destruction doit être présent (articles, configuration, etc.).

## Restauration cross-namespace (Optionnel)

Si vous souhaitez restaurer dans un namespace différent :

```bash
# Créer le nouveau namespace
kubectl create namespace ghost-tp-restored

# Restaurer avec mapping de namespace
tridentctl-protect create br ghost-restore2 \
  --namespace-mapping ghost-tp:ghost-tp-restored \
  --appvault ontap-vault \
  --path <backup-path> \
  -n ghost-tp-restored \
  --dry-run | kubectl apply -f -
```

## Dépannage

### La restauration échoue

```bash
# Vérifier les détails de la restauration
kubectl describe backupinplacerestore ghost-restore1 -n ghost-tp

# Vérifier les logs Trident Protect
kubectl logs -n trident-protect -l app=trident-protect-controller-manager --tail=100

# Vérifier l'AppVault
tridentctl-protect get appvault ontap-vault -n trident-protect
```

### Le pod ne démarre pas

```bash
# Vérifier les logs
kubectl logs -n ghost-tp -l app.kubernetes.io/name=ghost-tp

# Vérifier les événements
kubectl get events -n ghost-tp --sort-by='.lastTimestamp'

# Vérifier que le PVC est lié
kubectl describe pvc blog-content -n ghost-tp
```

### Les données ne sont pas restaurées

```bash
# Vérifier que le backup contenait des données
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --show-paths \
  --app ghost-app \
  -n trident-protect

# Vérifier que le volume est monté correctement
kubectl describe pod -n ghost-tp -l app.kubernetes.io/name=ghost-tp
```

## Validation finale

Pour valider que la restauration est complète :

1. ✅ L'application Ghost est accessible
2. ✅ Le contenu créé avant la destruction est présent
3. ✅ Les articles sont visibles
4. ✅ La configuration est restaurée

## Prochaines étapes

Une fois la restauration validée, vous avez terminé le TP complet ! 🎉

Vous pouvez maintenant :

- Explorer d'autres fonctionnalités de Trident Protect
- Tester des scénarios de disaster recovery
- Configurer des schedules automatiques

---

**Félicitations ! Vous avez complété le TP Ghost avec Trident Protect !** 🚀
