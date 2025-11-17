# TP Complet : Ghost avec Trident et Trident Protect

## Vue d'ensemble

Ce TP complet vous guide à travers l'installation et l'utilisation de Trident et Trident Protect pour protéger une application Ghost déployée sur Kubernetes avec un backend ONTAP NFS.

## Objectifs pédagogiques

À la fin de ce TP, vous serez capable de :

1. Installer et configurer Trident (provisionneur de volumes CSI)
2. Installer et configurer Trident Protect (solution de sauvegarde/restauration)
3. Déployer une application Ghost avec stockage persistant NFS ONTAP
4. Protéger l'application avec Trident Protect
5. Créer des snapshots et backups de l'application
6. Détruire et restaurer l'application depuis un backup

## Prérequis

Avant de commencer, assurez-vous d'avoir :

- Un cluster Kubernetes fonctionnel (version 1.17+)
- Un backend ONTAP configuré et accessible
- Les credentials ONTAP (username/password)
- Un registry Docker privé (optionnel, pour les images)
- Helm installé (version 3.x)
- Accès administrateur au cluster Kubernetes
- Un bucket S3 pour Trident Protect (AppVault)

Voir la section [0_Prerequisites](0_Prerequisites/) pour les vérifications détaillées.

## Structure du TP

Ce TP est organisé en 8 étapes séquentielles :

1. **[0_Prerequisites](0_Prerequisites/)** - Vérification des prérequis
2. **[1_Install_Trident](1_Install_Trident/)** - Installation de Trident 25.10
3. **[2_Install_TridentProtect](2_Install_TridentProtect/)** - Installation de Trident Protect
4. **[3_Deploy_Ghost](3_Deploy_Ghost/)** - Déploiement de l'application Ghost
5. **[4_Protect_Ghost](4_Protect_Ghost/)** - Activation de la protection Trident Protect
6. **[5_Backup_Ghost](5_Backup_Ghost/)** - Création de snapshots et backups
7. **[6_Destroy_Ghost](6_Destroy_Ghost/)** - Destruction de l'application
8. **[7_Restore_Ghost](7_Restore_Ghost/)** - Restauration depuis backup

## Exécution rapide

Pour exécuter toutes les étapes automatiquement :

```bash
cd Kubernetes_v6/Trident_Protect_Scenarios/Scenario12_Ghost_TP
./all_in_one.sh
```

## Exécution étape par étape

Pour suivre le TP étape par étape et comprendre chaque opération :

1. Commencez par vérifier les prérequis : `cd 0_Prerequisites && ./check_prerequisites.sh`
2. Suivez chaque étape dans l'ordre en lisant les README.md de chaque section
3. Exécutez les scripts fournis ou suivez les commandes manuelles

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Trident    │  │   Trident   │  │    Ghost     │        │
│  │              │  │   Protect   │  │  Application │        │
│  │  (CSI)       │  │  (Backup)   │  │              │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
│         │                 │                 │                │
│         └─────────────────┴─────────────────┘                │
│                            │                                  │
└────────────────────────────┼──────────────────────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  ONTAP Backend  │
                    │   (NFS Storage) │
                    └─────────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │   AppVault S3   │
                    │  (Backups)      │
                    └─────────────────┘
```

## Flux du TP

1. **Installation** : Trident → Trident Protect
2. **Déploiement** : Ghost avec PVC NFS
3. **Protection** : Création d'une Application Trident Protect
4. **Backup** : Snapshot → Backup vers AppVault
5. **Destruction** : Suppression de l'application
6. **Restauration** : Restauration depuis backup → Vérification des données

## Points d'attention

- **Labels cohérents** : Les labels doivent être identiques entre Deployment, PVC et Service pour que Trident Protect puisse identifier l'application
- **AppVault** : Doit être créé avant l'étape 4 (peut être fait dans l'étape 2)
- **Storage Class** : Doit exister avant le déploiement de Ghost
- **Backend ONTAP** : Doit être configuré avant le déploiement de Ghost
- **Données de test** : Important de créer du contenu dans Ghost avant le backup pour valider la restauration

## Validation du TP

À la fin du TP, vous devez pouvoir :

- ✅ Accéder au site Ghost restauré (<http://IP:30080>)
- ✅ Voir le contenu créé avant la destruction
- ✅ Comprendre le flux complet : déploiement → protection → backup → destruction → restauration

## Dépannage

En cas de problème :

1. Vérifier les logs : `kubectl logs -n trident-protect -l app=trident-protect-controller-manager`
2. Vérifier l'état de Trident : `tridentctl -n trident version`
3. Vérifier l'état de Trident Protect : `tridentctl-protect version`
4. Vérifier les pods : `kubectl get pods -n trident` et `kubectl get pods -n trident-protect`

## Ressources supplémentaires

- Documentation Trident : `Documentation_Trident/`
- Scénarios Trident : `Kubernetes_v6/Trident_Scenarios/`
- Scénarios Trident Protect : `Kubernetes_v6/Trident_Protect_Scenarios/`

## Durée estimée

- Installation (étapes 0-2) : ~30 minutes
- Déploiement et protection (étapes 3-4) : ~15 minutes
- Backup et restauration (étapes 5-7) : ~20 minutes
- **Total** : ~1h15

---

**Bon TP !** 🚀
