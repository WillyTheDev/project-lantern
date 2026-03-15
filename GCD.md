🔦 PROJECT LANTERN (Working Title)
Genre : Social-Extraction Crawler (PvPvE non-shooter)

Plateforme : PC (3D stylisée)

Pilier central : L'incarnation de "l'ordinaire" dans un monde persistant où la survie dépend de la coopération et du prestige social.

1. LA BOUCLE DE JEU (Core Loop)
PRÉPARER (Le Village) : Incarner son rôle, interagir avec le **Coffre de Provisions (Supplies Chest)** pour s'équiper, commercer avec les autres, fabriquer ou acheter des consommables (lanternes, cordes, potions, nourriture).

S'AVENTURER (Le Donjon) : Entrer dans une instance instable (D&D style) avec un groupe ou en solo pour récolter des trésors et matériaux rares.

EXTRAIRE (La Tension) : Atteindre la zone de sortie vivant. En cas de mort, tout le butin accumulé est perdu.

BRILLER (Le Prestige) : Utiliser le butin pour débloquer des cosmétiques uniques et monter en grade visuel dans le village.

2. LES DEUX MONDES
A. Le Hub : Le Village Persistant
Atmosphère : Paisible, communautaire, sécurisant.

Objectif Social : Un lieu de rencontre où la "vie ordinaire" est valorisée. Les joueurs timides peuvent s'accomplir via l'artisanat et la récolte sans forcément entrer dans le donjon.

Système de Reconnaissance : * Pas de statistiques de combat (+10 force).

Progression 100% cosmétique et utilitaire (grades, titres, apparences rares).

La visibilité sociale est la récompense : "L'élite" est immédiatement identifiable par son équipement visuel.

B. L'Instance : Le Donjon Hebdomadaire
Structure : Salles générées procéduralement (agilité, énigmes physiques, combats tactiques, boss).

Le Donjon Unique : Le donjon est réinitialisé chaque semaine, créant un événement communautaire.

L'Extraction : Une limite d'entrées (ex: une par semaine ou par jour) pour maximiser la valeur de chaque tentative et éviter le "farm" intensif.

3. MÉCANIQUES DE GAMEPLAY VALIDÉES
Le Système de Rencontre (PvPvE)
Les joueurs peuvent croiser d'autres groupes dans le donjon.

Le Dilemme : Coopérer pour franchir une salle difficile OU voler le butin de l'autre groupe.

Le vol est possible mais risqué et marqué socialement.

L'Interaction Physique (Non-Shooter)
Utilisation de la physique 3D pour les énigmes et le combat.

Communication
Mix de chat textuel (pour le RP et le commerce), emotes contextuelles et signes visuels (grades).

L'Interaction Vocale (Spatial VOIP)
Système de voix de proximité 3D (Spatial Audio) utilisant le codec Opus pour la performance.
Indicateur visuel au-dessus du joueur lors de la parole.
Réduction du bruit (RNNoise) et détection d'activité (VAD) avec Hang-Time pour une communication fluide.

Le "Juice" de Combat & Interactions
- **Squash & Stretch (Squeeze) :** Animation procédurale lors de la prise de dégâts (0.2s cooldown) appliquée uniquement sur les nodes visuels pour préserver l'intégrité de la physique Jolt.
- **Système de Knockback :** Système synchronisé serveur-client permettant de repousser les joueurs et les ennemis lors des attaques ou via les dangers environnementaux.
- **Secousses de Caméra (Screen Shake) :** Feedback visuel subtil lors de la réception de dégâts pour renforcer l'impact sans nuire à la lisibilité du combat.
- **Optimisation des Dangers :** Les zones de dégâts (HazardAreas) appliquent des dégâts et du knockback à intervalle fixe (0.5s) pour une meilleure performance réseau.

4. DIRECTION TECHNIQUE & ARTISTIQUE
Moteur : 3D (pour l'immersion, la verticalité et la gestion des ombres portées).

Style Visuel : Stylisé (permet de mettre l'accent sur les silhouettes des joueurs et la lumière des lanternes).

Infrastructure : Hybride (Hub persistant massif + Instances de donjons synchronisées).

5. OBJECTIF DU PROOF OF CONCEPT (PoC)
Réaliser une "Vertical Slice" comprenant :

- Un contrôleur de personnage 3D avec inventaire persistant.

- Un hub miniature avec un **Coffre de Provisions** interactif pour tester l'acquisition et la sauvegarde d'objets.

- Une transition fonctionnelle vers une instance de 3 salles (1 Agilité, 1 Rencontre PvPvE, 1 Sortie).

6. FEUILLE DE ROUTE (Prochaines Étapes)
La phase de Proof of Concept étant stabilisée, les prochaines itérations se concentreront sur la profondeur de gameplay et la robustesse technique :

- **Génération Procédurale des Donjons :** Passage d'une structure statique à un générateur de salles basé sur des tuiles (tileset), géré intégralement par le serveur pour garantir l'équité.
- **Systèmes Sociaux Avancés :** Mise en place d'un système de groupes (Party), du commerce entre joueurs sécurisé dans le Hub, et d'emotes pour enrichir l'interaction vocale.
- **Affinement de la Boucle d'Extraction :** Introduction de chronomètres d'instance (effondrement du donjon), de raretés d'objets avec statistiques aléatoires, et de consommables utilitaires (soins, buffs).
- **IA de Combat Évoluée :** Diversification du bestiaire (attaques à distance, supports) et mécaniques de boss à plusieurs phases.
- **Sécurité et Polissage Technique :** Migration de la santé des joueurs vers un modèle 100% serveur (Server-Authoritative), persistance totale des niveaux/XP sur PocketBase, et ajout de VFX/SFX immersifs.
