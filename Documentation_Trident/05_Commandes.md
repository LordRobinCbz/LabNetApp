# Top commandes

## Commandes tridentctl

### Informations générales

```bash
# Version de Trident
tridentctl -n trident version

# Informations sur l'installation
tridentctl -n trident get installation
```

### Gestion des backends

```bash
# Lister tous les backends
tridentctl -n trident get backend

# Détails d'un backend spécifique
tridentctl -n trident get backend <backend-name>

# Créer un backend depuis un fichier JSON
tridentctl -n trident create backend -f backend.json

# Mettre à jour un backend
tridentctl -n trident update backend <backend-name> -f backend.json

# Supprimer un backend
tridentctl -n trident delete backend <backend-name>
```

### Gestion des volumes

```bash
# Lister tous les volumes
tridentctl -n trident get volume

# Détails d'un volume
tridentctl -n trident get volume <volume-name>

# Lister les volumes d'un backend spécifique
tridentctl -n trident get volume --backend <backend-name>

# Supprimer un volume
tridentctl -n trident delete volume <volume-name>
```

### Gestion des Storage Classes

```bash
# Lister les Storage Classes gérées par Trident
tridentctl -n trident get storageclass

# Détails d'une Storage Class
tridentctl -n trident get storageclass <storageclass-name>
```

### Snapshots

```bash
# Lister les snapshots
tridentctl -n trident get snapshot

# Détails d'un snapshot
tridentctl -n trident get snapshot <snapshot-name>
```

### Commandes de diagnostic

```bash
# Logs du contrôleur
tridentctl -n trident logs controller

# Logs d'un nœud spécifique
tridentctl -n trident logs node <node-name>

# Informations de diagnostic
tridentctl -n trident diagnose
```

## Commandes kubectl pour Trident

### Namespace Trident

```bash
# Lister tous les pods Trident
kubectl get pods -n trident

# Détails du contrôleur
kubectl describe pod -n trident -l app=trident-controller

# Logs du contrôleur
kubectl logs -n trident -l app=trident-controller --tail=100

# Logs des nœuds
kubectl logs -n trident -l app=trident-node --tail=100
```

### TridentOrchestrator

```bash
# Statut de l'orchestrator
kubectl get torc -n trident

# Détails complets
kubectl describe torc trident -n trident

# Vérifier le statut d'installation
kubectl get torc trident -n trident -o jsonpath='{.status.status}'
```

### TridentBackendConfig

```bash
# Lister les backends
kubectl get tbc -n trident

# Détails d'un backend
kubectl describe tbc <backend-name> -n trident

# Éditer un backend
kubectl edit tbc <backend-name> -n trident

# Supprimer un backend
kubectl delete tbc <backend-name> -n trident
```

### Volumes et PVC

```bash
# Lister les PVC
kubectl get pvc -A

# Détails d'un PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Lister les PV
kubectl get pv

# Détails d'un PV
kubectl describe pv <pv-name>

# Événements liés à un PVC
kubectl get events -n <namespace> --field-selector involvedObject.name=<pvc-name>
```

### Snapshots CSI

```bash
# Lister les VolumeSnapshots
kubectl get volumesnapshot -A

# Détails d'un snapshot
kubectl describe volumesnapshot <snapshot-name> -n <namespace>

# Lister les VolumeSnapshotContents
kubectl get volumesnapshotcontent

# Créer un snapshot depuis un PVC
kubectl create volumesnapshot <snapshot-name> \
  --source=<pvc-name> \
  --snapshot-class=csi-snap-class \
  -n <namespace>
```

## Commandes pour le dépannage

### Vérifier la connectivité

```bash
# Tester la connexion au backend ONTAP
ping <management-lif>

# Tester NFS
showmount -e <data-lif>

# Tester iSCSI
iscsiadm -m discovery -t st -p <data-lif>
```

### Vérifier les montages

```bash
# Sur un nœud, vérifier les montages NFS
mount | grep nfs

# Vérifier les sessions iSCSI
iscsiadm -m session

# Vérifier le multipathing
multipath -ll
```

### Logs et événements

```bash
# Événements du namespace Trident
kubectl get events -n trident --sort-by='.lastTimestamp'

# Événements d'un namespace d'application
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Logs avec filtrage
kubectl logs -n trident -l app=trident-controller | grep -i error

# Logs en temps réel
kubectl logs -n trident -l app=trident-controller -f
```

### Vérifier les ressources

```bash
# Utilisation des ressources par les pods Trident
kubectl top pods -n trident

# Utilisation des ressources par les nœuds
kubectl top nodes

# Détails des ressources d'un pod
kubectl describe pod <pod-name> -n trident
```

## Commandes ONTAP

### Via SSH

```bash
# Se connecter à ONTAP
ssh admin@<management-lif>

# Lister les volumes
vol show

# Lister les LUNs
lun show

# Vérifier les export policies
export-policy rule show

# Vérifier les snapshots
snapshot show
```

### Via REST API

```bash
# Lister les volumes
curl -X GET -ku admin:password \
  "https://<cluster>/api/storage/volumes" \
  -H "accept: application/json"

# Créer un volume
curl -X POST -ku admin:password \
  "https://<cluster>/api/storage/volumes" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test_vol",
    "svm": {"name": "svm_name"},
    "size": 1073741824
  }'
```

## Commandes Trident Protect

### Installation et configuration

```bash
# Version de Trident Protect
tridentctl-protect version

# Lister les AppVaults
tridentctl-protect get appvault -n trident-protect

# Créer un AppVault
tridentctl-protect create appvault <name> \
  -s <secret-name> \
  --bucket <bucket-name> \
  --endpoint <endpoint> \
  -n trident-protect
```

### Gestion des applications

```bash
# Créer une application
tridentctl-protect create app <app-name> \
  --namespaces <namespace> \
  -n <namespace>

# Lister les applications
tridentctl-protect get app -n <namespace>

# Détails d'une application
tridentctl-protect get app <app-name> -n <namespace>
```

### Snapshots et backups

```bash
# Créer un snapshot
tridentctl-protect create snapshot <snapshot-name> \
  --app <app-name> \
  --appvault <appvault-name> \
  -n <namespace>

# Lister les snapshots
tridentctl-protect get snap -n <namespace>

# Créer un backup
tridentctl-protect create backup <backup-name> \
  --app <app-name> \
  --snapshot <snapshot-name> \
  --appvault <appvault-name> \
  -n <namespace>

# Lister les backups
tridentctl-protect get backup -n <namespace>
```

### Restauration

```bash
# Restaurer un snapshot vers un nouveau namespace
tridentctl-protect create sr <restore-name> \
  --namespace-mapping <source>:<target> \
  --snapshot <namespace>/<snapshot-name> \
  -n <target-namespace>

# Restaurer un backup in-place
tridentctl-protect create bir <restore-name> \
  --backup <namespace>/<backup-name> \
  -n <namespace>

# Restaurer un backup vers un autre cluster
tridentctl-protect create br <restore-name> \
  --namespace-mapping <source>:<target> \
  --appvault <appvault-name> \
  --path <backup-path> \
  -n <target-namespace> \
  --context <kubeconfig-context>
```

## Scripts utiles

### Vérification rapide

```bash
#!/bin/bash
# check-trident.sh

echo "=== Trident Status ==="
kubectl get pods -n trident
echo ""
echo "=== Backends ==="
tridentctl -n trident get backend
echo ""
echo "=== Volumes ==="
tridentctl -n trident get volume
```

### Nettoyage des volumes orphelins

```bash
#!/bin/bash
# cleanup-orphaned-volumes.sh

# Lister les volumes sans PVC associé
for vol in $(tridentctl -n trident get volume -o json | jq -r '.[] | select(.pvc == null) | .name'); do
  echo "Suppression du volume orphelin: $vol"
  tridentctl -n trident delete volume $vol
done
```

## Autocomplétion

Pour activer l'autocomplétion bash :

```bash
# Pour tridentctl
mkdir -p ~/.bash/completions
tridentctl completion bash > ~/.bash/completions/tridentctl-completion.bash
source ~/.bash/completions/tridentctl-completion.bash
echo 'source ~/.bash/completions/tridentctl-completion.bash' >> ~/.bashrc

# Pour tridentctl-protect
tridentctl-protect completion bash > ~/.bash/completions/tridentctl-protect-completion.bash
source ~/.bash/completions/tridentctl-protect-completion.bash
echo 'source ~/.bash/completions/tridentctl-protect-completion.bash' >> ~/.bashrc
```

## Ressources supplémentaires

- Documentation officielle : <https://docs.netapp.com/us-en/trident/>
- GitHub : <https://github.com/NetApp/trident>
- Exemples de configuration : Voir les scénarios dans `Kubernetes_v6/Trident_Scenarios/`
