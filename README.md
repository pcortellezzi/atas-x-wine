# atas-x-wine

Couche de compatibilité et d'intégration pour faire fonctionner la plateforme de trading **ATAS X** sous Linux via Wine/Proton et Wayland.

---

## 🚀 Fonctionnalités
* **Hook DLL C++ Synchrone** : Intercepte les appels système `SetWindowPos` et `DeferWindowPos` pour masquer proprement les graphiques Vulkan inactifs.
* **Lanceur d'Injection Suspendue** : Démarre ATAS et injecte le Hook en mémoire avant l'initialisation de l'affichage.
* **Spoofing HWID / WMI** : Contourne les vérifications d'identification de carte mère pour l'activation.
* **Zéro Gamescope requis** : Fonctionne directement sur votre compositeur Wayland natif (KDE Plasma, GNOME, etc.).

---

## 🛠 Structure du Projet
* `flake.nix` : Définition du paquet NixOS croisant la compilation C++ et configurant le préfixe Wine.
* `atas_launcher.cpp` : Code source du lanceur par injection de thread distant (Windows 64 bits).
* `window_hider_hook.cpp` : Code source du Hook DLL Win32 pour le masquage des fenêtres.
* `dist/` : Paquet universel et autonome pour les autres distributions Linux (Ubuntu, Arch, etc.).
  - `install_atas.sh` : Script d'installation automatique (Proton, winetricks, patches).
  - `DISTRIBUTION_GUIDE.md` : Guide d'installation complet pour les non-NixOS.

---

## 📦 Utilisation sous NixOS / Nix Flakes

### 1. Entrer dans l'environnement de développement
```bash
nix develop
```

### 2. Première installation d'ATAS
Téléchargez l'installeur officiel d'ATAS (`ATAS_Setup.exe`), puis lancez :
```bash
atas --install /chemin/vers/ATAS_Setup.exe
```

### 3. Lancer ATAS
Une fois installé, démarrez simplement l'application avec :
```bash
atas
```

### 4. Mettre à jour ATAS
```bash
atas-updater
```

---

## 🐧 Utilisation sur d'autres distributions (Ubuntu, Arch, Fedora)

Consultez le guide détaillé [dist/DISTRIBUTION_GUIDE.md](dist/DISTRIBUTION_GUIDE.md) pour installer l'application en dehors de NixOS à l'aide de notre package autonome universel.
