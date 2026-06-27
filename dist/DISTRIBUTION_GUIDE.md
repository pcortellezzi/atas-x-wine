# Guide de Distribution et d'Installation Autonome d'ATAS sous Linux

Ce guide détaille comment installer et faire fonctionner la plateforme de trading **ATAS** sur n'importe quelle distribution Linux (Ubuntu, Arch, Debian, Fedora, etc.) en bénéficiant du masquage synchrone des sous-surfaces Vulkan sous Wayland.

---

## 📋 Prérequis Système

Pour que l'installation et le rendu graphique fonctionnent de manière fluide :
1. **Session Wayland active** (KDE Plasma Wayland ou GNOME Wayland). Le pilote natif Wayland de Wine (`winewayland.drv`) est exploité pour le fenêtrage.
2. **Pilotes Vulkan installés** et fonctionnels pour votre carte graphique (Mesa RADV pour AMD, pilote NVIDIA officiel pour NVIDIA).
3. **Utilitaires système requis** :
   - `wget` et `tar` (pour le téléchargement et l'extraction de Proton).
   - `python3` (pour l'application automatique des patchs de contournement d'identification de carte mère / HWID).
   - `winetricks` (pour l'installation automatique des dépendances logicielles de Windows).
   - `wine` (une version système de Wine installée pour enregistrer les chargeurs).

---

## 📦 Contenu du Dossier d'Installation

Le dossier `dist/` contient tous les éléments précompilés et scripts automatisés nécessaires :
* [install_atas.sh](file:///home/philippe/Projects/ATAS/dist/install_atas.sh) : Le script d'installation automatique et d'initialisation du préfixe.
* [atas_launcher.exe](file:///home/philippe/Projects/ATAS/dist/atas_launcher.exe) : Notre binaire d'injection suspendue C++ (statique).
* [window_hider_hook.dll](file:///home/philippe/Projects/ATAS/dist/window_hider_hook.dll) : Notre DLL de Hook C++ détournant les appels `SetWindowPos` et `DeferWindowPos` pour masquer proprement les graphiques inactifs sous Wayland.
* [patch_wbemprox.py](file:///home/philippe/Projects/ATAS/dist/patch_wbemprox.py) : Script Python appliquant les modifications HWID / spoofing directement dans les DLL de Proton.

---

## 🛠 Procédure d'Installation

1. Ouvrez un terminal dans le dossier contenant le script `install_atas.sh` et le fichier d'installation d'ATAS (ex: `ATAS_X_latest.exe`).
2. Rendez le script exécutable :
   ```bash
   chmod +x install_atas.sh
   ```
3. Exécutez l'installation en passant le chemin de l'installeur Windows d'ATAS en paramètre :
   ```bash
   ./install_atas.sh /chemin/vers/ATAS_X_latest.exe
   ```

### Que fait le script d'installation ?
1. **Vérifie et configure Proton** : Télécharge automatiquement `GE-Proton11-1`, l'extrait et applique le patch binaire de spoofing HWID sur `wbemprox.dll` pour que la licence ATAS s'active sans erreur.
2. **Initialise le WINEPREFIX** : Crée un préfixe Wine 64 bits isolé dans `~/.local/share/atas-linux/prefix`.
3. **Installe les Dépendances Windows** : Installe de manière silencieuse via `winetricks` les composants requis :
   - `vcrun2022` (runtimes Microsoft Visual C++).
   - `dotnetdesktop8` (runtime .NET 8 Desktop).
   - `winhttp` et `d3dcompiler_47` (requis par le moteur d'ATAS).
   - `corefonts` (polices standard).
4. **Applique les correctifs de Registre** : Modifie la base de registre Wine pour activer le pilote graphique Wayland natif, injecte les identifiants processeur/disque durs spoofés, et active le contournement de l'infrastructure WMI.
5. **Déploie la DLL de Hook** : Installe le lanceur par injection de DLL pour éliminer le bug de superposition graphique.
6. **Lance l'installeur d'ATAS**.

---

## 🚀 Lancement d'ATAS

Une fois l'installation terminée, vous pouvez démarrer ATAS à tout moment via le script généré :
```bash
~/.local/share/atas-linux/atas.sh
```

Ce script configure l'ensemble des variables d'environnement nécessaires au moteur Vulkan / Skia d'ATAS (ex: `AVALONIA_RENDERER=vulkan`, `WINEFSYNC=1`, etc.) et exécute l'application de façon fluide.
