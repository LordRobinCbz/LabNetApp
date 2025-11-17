# Use case de démonstration: Restore

## Vue d'ensemble

Trident Protect offre plusieurs méthodes de restauration pour récupérer des applications depuis des snapshots ou des backups. Cette démonstration couvre les différents scénarios de restauration.

## Types de restauration

### 1. Restauration depuis un snapshot

- **In-place** : Restaure dans le même namespace
- **Cross-namespace** : Restaure dans un nouveau namespace
- **Partielle** : Restaure seulement certains volumes

### 2. Restauration depuis un backup

- **In-place** : Restaure dans le même namespace
- **Cross-namespace** : Restaure dans un nouveau namespace
- **Cross-cluster** : Restaure sur un cluster différent
- **Partielle** : Restaure seulement certains volumes

## Prérequis

- Une application sauvegardée (voir [06_UseCase_Backup.md](06_UseCase_Backup.md))
- Au moins un snapshot ou backup disponible
- Les permissions nécessaires pour créer des ressources dans le namespace cible

## Restauration depuis un snapshot

### Restauration in-place

Pour restaurer un snapshot dans le même namespace :

```bash
# 1. Mettre à l'échelle l'application à 0 (volumes doivent être détachés)
kubectl -n tpsc05busybox scale deploy busybox --replicas=0

# 2. Créer un TridentActionSnapshotRestore
cat << EOF | kubectl apply -f -
apiVersion: trident.netapp.io/v1
kind: TridentActionSnapshotRestore
metadata:
  name: mydatarestore
  namespace: tpsc05busybox
spec:
  pvcName: mydata1
  volumeSnapshotName: <snapshot-name>
EOF

# 3. Vérifier le statut
kubectl get tasr -n tpsc05busybox

# 4. Remettre l'application en service
kubectl -n tpsc05busybox scale deploy busybox --replicas=1
```

### Restauration vers un nouveau namespace

Pour restaurer un snapshot dans un nouveau namespace :

```bash
# 1. Créer le namespace cible (par l'admin)
kubectl create ns tpsc05busyboxsr

# 2. Restaurer le snapshot
tridentctl-protect create sr bboxsr1 \
  -n tpsc05busyboxsr \
  --namespace-mapping tpsc05busybox:tpsc05busyboxsr \
  --snapshot tpsc05busybox/bboxsnap1 \
  --dry-run | kubectl apply -f -

# 3. Vérifier le statut
tridentctl-protect get sr -n tpsc05busyboxsr

# 4. Vérifier l'application restaurée
kubectl -n tpsc05busyboxsr get pod,pvc
```

## Restauration depuis un backup

### Restauration in-place

Pour restaurer un backup dans le même namespace après suppression de l'application :

```bash
# 1. Supprimer l'application (si elle existe encore)
kubectl delete -n tpsc05busybox deploy busybox
kubectl delete -n tpsc05busybox pvc --all

# 2. Restaurer le backup
tridentctl-protect create bir bboxbir1 \
  -n tpsc05busybox \
  --backup tpsc05busybox/bboxbkp1 \
  --dry-run | kubectl apply -f -

# 3. Vérifier le statut
tridentctl-protect get bir -n tpsc05busybox

# 4. Vérifier que l'application est restaurée
kubectl -n tpsc05busybox get pod,pvc

# 5. Vérifier les données
kubectl exec -n tpsc05busybox $(kubectl get pod -n tpsc05busybox -o name) -- \
  cat /data1/file.txt
```

### Restauration vers un nouveau namespace

Pour restaurer un backup dans un nouveau namespace :

```bash
# 1. Créer le namespace cible
kubectl create ns tpsc05busyboxbr

# 2. Restaurer le backup
tridentctl-protect create sr bboxsr1 \
  -n tpsc05busyboxbr \
  --namespace-mapping tpsc05busybox:tpsc05busyboxbr \
  --snapshot tpsc05busybox/bboxsnap1 \
  --dry-run | kubectl apply -f -

# 3. Vérifier le statut
tridentctl-protect get sr -n tpsc05busyboxbr
```

### Restauration cross-cluster

Pour restaurer un backup sur un cluster Kubernetes différent :

#### Préparation sur le cluster source

```bash
# 1. Lister les backups disponibles
tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --show-paths \
  --app bbox \
  -n trident-protect

# 2. Récupérer le chemin du backup
BKPPATH=$(tridentctl-protect get appvaultcontent ontap-vault \
  --show-resources backup \
  --show-paths \
  --app bbox \
  -n trident-protect | grep bboxbkp1 | awk -F '|' '{print $11}')
```

#### Configuration sur le cluster cible

```bash
# 1. Vérifier que l'AppVault existe sur le cluster cible
tridentctl-protect get appvault ontap-vault \
  -n trident-protect \
  --context <kubeconfig-context>

# 2. Créer le namespace cible
kubectl create ns tpsc05busyboxbr --context <kubeconfig-context>

# 3. Restaurer le backup
tridentctl-protect create br bboxbr1 \
  -n tpsc05busyboxbr \
  --namespace-mapping tpsc05busybox:tpsc05busyboxbr \
  --appvault ontap-vault \
  --storageclass-mapping storage-class-nfs:sc-nfs \
  --path $BKPPATH \
  --context <kubeconfig-context> \
  --dry-run | kubectl apply -f - --context <kubeconfig-context>

# 4. Vérifier le statut
tridentctl-protect get br -n tpsc05busyboxbr --context <kubeconfig-context>

# 5. Vérifier l'application
kubectl get pod,pvc -n tpsc05busyboxbr --context <kubeconfig-context>
```

## Restauration partielle

Pour restaurer seulement certains volumes d'une application :

```bash
# Exemple : Restaurer seulement mydata1
tridentctl-protect create bir bboxbir1 \
  -n tpsc05busybox \
  --backup tpsc05busybox/bboxbkp1 \
  --resource-filter-include='[{"labelSelectors":["volume=mydata1"]}]' \
  --dry-run | kubectl apply -f -
```

## Restauration avec hooks

Les hooks post-restore peuvent être utilisés pour :

- Réinitialiser des configurations
- Redémarrer des services
- Exécuter des scripts de post-restauration

Voir le [Scenario06](../../Kubernetes_v6/Trident_Protect_Scenarios/Scenario06) pour des exemples détaillés.

## Disaster Recovery (DR)

### Failover

En cas de perte du cluster primaire :

1. Accéder au cluster secondaire
2. Vérifier l'accès à l'AppVault
3. Restaurer les applications critiques depuis les backups
4. Mettre à jour les DNS/routing si nécessaire

### Failback

Pour revenir au cluster primaire après réparation :

1. Synchroniser les données si nécessaire
2. Restaurer sur le cluster primaire
3. Rediriger le trafic vers le cluster primaire
4. Mettre à jour les backups depuis le cluster primaire

## Mapping des ressources

### Mapping des namespaces

Lors de la restauration vers un nouveau namespace ou cluster, vous pouvez mapper les namespaces :

```bash
--namespace-mapping source-ns:target-ns
```

### Mapping des Storage Classes

Lors de la restauration cross-cluster, vous pouvez mapper les Storage Classes :

```bash
--storageclass-mapping source-sc:target-sc
```

## Vérification post-restauration

### 1. Vérifier les pods

```bash
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
```

### 2. Vérifier les PVC

```bash
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>
```

### 3. Vérifier les données

```bash
# Lister les fichiers
kubectl exec -n <namespace> <pod-name> -- ls /data

# Lire le contenu
kubectl exec -n <namespace> <pod-name> -- cat /data/file.txt
```

### 4. Vérifier l'intégrité de l'application

- Tester les fonctionnalités de l'application
- Vérifier les connexions aux bases de données
- Valider les configurations

## Dépannage

### Problèmes courants

1. **Restauration en échec**

   ```bash
   # Vérifier les événements
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'

   # Vérifier les logs Trident Protect
   kubectl logs -n trident-protect -l app=trident-protect-controller-manager
   ```

2. **PVC en état Pending**

   ```bash
   # Vérifier les Storage Classes
   kubectl get sc

   # Vérifier les backends Trident
   tridentctl -n trident get backend
   ```

3. **Données manquantes**
   - Vérifier que le backup est complet
   - Vérifier les logs de restauration
   - Vérifier l'accès à l'AppVault

## Bonnes pratiques

1. **Testez régulièrement** : Effectuez des tests de restauration réguliers
2. **Documentation** : Documentez les procédures de restauration
3. **Automation** : Automatisez les tests de restauration quand possible
4. **Monitoring** : Surveillez les opérations de restauration
5. **RTO/RPO** : Définissez vos objectifs de temps de récupération et de point de récupération

## Scénarios avancés

### Restauration avec deux buckets

Pour utiliser un bucket source et un bucket cible différents, voir le [Scenario10](../../Kubernetes_v6/Trident_Protect_Scenarios/Scenario10).

### Restauration de machines virtuelles

Pour restaurer des machines virtuelles avec KubeVirt, voir le [Scenario11](../../Kubernetes_v6/Trident_Protect_Scenarios/Scenario11).

## Conclusion

Trident Protect offre une flexibilité complète pour restaurer des applications dans différents scénarios, depuis la restauration simple in-place jusqu'au disaster recovery cross-cluster. La clé est de bien comprendre vos besoins et de tester régulièrement vos procédures de restauration.
