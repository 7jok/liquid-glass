# Installer Liquid Glass sur un nouveau PC (instructions pour Claude)

Ce fichier est à donner à Claude Code sur un PC où **Omarchy** vient d'être installé.
Il reproduit à l'identique les ajouts du PC d'origine : interfaces (profil Mac et bureau
Linux avec ses 20 styles, dont 7JOKS et Infini), thèmes, fonds d'écran, écrans de verrouillage, raccourcis,
réglages, fond actuel et photo du compte. Il n'installe **pas** toutes les applications
de l'ancien PC, seulement ce dont Liquid Glass a besoin.

Dépôt (privé) : https://github.com/7jok/liquid-glass

---

## Pour Claude : étapes à suivre

Parle en français à l'utilisateur, avec des messages courts.

1. **Vérifier la base.** `command -v omarchy hyprctl` doit répondre. Sinon, arrête-toi :
   il faut d'abord installer Omarchy (https://omarchy.org).

2. **Connexion GitHub** (le dépôt est privé). Si `gh auth status` dit « not logged in »,
   demande à l'utilisateur de taper dans le prompt :
   `! gh auth login`
   (choix : GitHub.com → HTTPS → Login with a web browser). N'essaie pas de le faire
   à sa place.

3. **Récupérer le dépôt** au même endroit que sur le PC d'origine :
   ```bash
   mkdir -p ~/Work
   gh repo clone 7jok/liquid-glass ~/Work/liquid-glass
   ```
   S'il existe déjà : `cd ~/Work/liquid-glass && git pull`.

4. **Installer les paquets nécessaires** (sudo : l'utilisateur tape son mot de passe).
   Demande-lui de lancer :
   `! cd ~/Work/liquid-glass && ./install.sh --packages`
   Ce premier passage fait aussi une sauvegarde de ses configs
   (`~/.config-backup-<date>` avec un `restore.sh`).

5. **Remettre les réglages, le fond et la photo** du PC d'origine :
   ```bash
   cd ~/Work/liquid-glass && ./install.sh --restore
   ```
   Ne combine pas `--packages` et `--restore` : ensemble, ils installeraient
   toutes les applications de l'ancien PC (`state/packages.txt`), ce que
   l'utilisateur ne veut pas, sauf s'il le demande.

6. **Vérifier** :
   - `hyprctl configerrors` est vide ;
   - `journalctl --user --since "-2min" -o cat | grep -i "load failed"` ne renvoie rien ;
   - `hyprctl layers -j` contient des couches `liquid-glass-…` ;
   - les fonds Wallhaven se téléchargent en arrière-plan
     (`~/.cache/liquid-glass/install-fonds.log`), les autres sont générés.

7. Dis-lui : **⌘⇧Espace** pour changer de style, **⌘K** pour l'aide-mémoire des
   raccourcis, menu  → Réglages Liquid Glass pour tout ajuster.

## Règles à respecter

- Ne jamais modifier `/usr/share/omarchy` ni `~/.bashrc`.
- Mechvibes (sons du clavier) : ne jamais ajouter l'utilisateur au groupe `input`,
  rien ne doit être donné aux autres applications.
- Ne pas voler le focus et ne pas changer d'espace de travail pendant les tests.
- Ne jamais pousser sur GitHub sans que l'utilisateur le demande.

---

## Garder les PC à jour

**Après des changements sur un PC** (réglages, fond, photo) :
```bash
cd ~/Work/liquid-glass
liquid-glass export
git add -A && git commit -m "Mes réglages" && git push
```

**Sur un autre PC, pour récupérer :**
```bash
cd ~/Work/liquid-glass && git pull && ./install.sh --restore
```
