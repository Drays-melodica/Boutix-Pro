# ⚡ BOUTIX PRO — Cyber Ops Console

## 📖 À propos

**BOUTIX PRO** est une application desktop de caisse enregistreuse et de gestion commerciale conçue pour les commerces de détail, boutiques et points de vente. 

Contrairement aux logiciels de caisse modernes souvent lourds, dépendants du cloud ou encombrés d'animations superflues, **BOUTIX PRO adopte une esthétique assumée d'invite de commande / BIOS rétro (DOS)** :
- **Efficacité brute :** Démarrage instantané, zéro latence dans la saisie.
- **Pilotage 100% Clavier :** Conçu pour les caissiers et gérants expérimentés, chaque action dispose de son raccourci direct.
- **Autonomie totale :** Fonctionne à 100% hors-ligne via une base de données embarquée SQLite. Aucune dépendance internet, vos données restent chez vous.

---

## ✨ Fonctionnalités Clés

### 🛒 Point de Vente & Caisse (POS)
- Encaissement ultra-rapide au clavier ou lecteur de code-barres.
- Gestion du panier en temps réel (quantités, remises, totaux HT & TTC).
- Prise en charge de multiples modes de règlement (espèces, carte, etc.).
- Impression automatique ou manuelle des tickets de caisse (imprimantes thermiques / ESC-POS ou PDF).

### 📦 Gestion du Catalogue & Fournisseurs
- Fiches articles complètes : référence, désignation, catégorie, taille, couleur, prix d'achat, prix de vente.
- Gestion des codes-barres avec module de génération et impression d'étiquettes personnalisées.
- Carnet d'adresses et gestion des fournisseurs associés aux articles.

### 📊 Suivi des Stocks & Traçabilité
- État des stocks en temps réel avec alerte visuelle sur les seuils critiques.
- Journal complet des mouvements de stocks (ventes, réassorts, pertes, inventaires).
- Historique détaillé et consultable de toutes les transactions de vente.

### 📈 Statistiques & Tableaux de Bord (Admin)
- Indicateurs clés en direct (Chiffre d'affaires, panier moyen, marge brute, etc.).
- Rapports périodiques d'activité.

### 🔒 Sécurité & Multi-utilisateurs
- Gestion des rôles et des permissions (Administrateur, Caissier).
- Sécurisation des accès par hachage cryptographique avec salt.
- Première configuration guidée au premier lancement.

---

## 🛠️ Stack Technique

- **Langage & Framework :** [Flutter](https://flutter.dev/) (Dart) pour Windows Desktop
- **Base de données :** [SQLite](https://sqlite.org/) via `sqflite_common_ffi`
- **Impression :** `printing` & `pdf` (tickets thermiques et étiquettes codes-barres)
- **Gestion des fenêtres :** `window_manager`
- **Design System :** Thème personnalisé ASCII / BIOS / MS-DOS en mode console rétro

---

## ⌨️ Raccourcis Clavier Principaux

| Raccourci | Action |
| :--- | :--- |
| `↑` / `↓` / `Entrée` | Navigation dans les menus et validation |
| `Échap` | Retour en arrière / Annulation / Fermeture de modal |
| `F1` à `F12` | Accès direct aux fonctions de caisse et modules |
| `Tab` / `Shift+Tab` | Navigation rapide entre les champs de formulaire |

---

## 🚀 Installation & Démarrage

### Utilisation directe (Windows)
Un installeur prêt à l'emploi est disponible dans le dossier `installer/` :
1. Téléchargez ou exécutez `Setup_BoutixPro.exe`.
2. Suivez les étapes de l'assistant d'installation.
3. Lancez **BOUTIX PRO** depuis votre bureau ou menu Démarrer.

### Environnement de développement

Prérequis :
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (>= 3.2.0)
- Outils de compilation C++ pour Windows (Visual Studio Build Tools)



# 3. Lancer l'application en mode desktop Windows
flutter run -d windows
