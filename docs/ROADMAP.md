# 🗺 Project Lantern Roadmap

This document outlines the detailed plan for future development iterations, following the stabilization of the core multiplayer infrastructure.

## 1. Procedural Dungeon Generation
Move away from static levels to dynamic, replayable instances.
- **Tile-Based Generator:** Assemble rooms and corridors from a predefined tileset on the Server.
- **Dynamic Navigation:** Rebaking of navigation meshes (Jolt/Godot) after generation.
- **Deterministic Seeding:** Use Server-provided seeds to ensure all clients (including late-joiners) see the same layout via the global `MultiplayerSpawner`.

## 2. Party & Social Systems
Enhance the "Social" pillar of the game.
- **Party Management:** UI and logic to form groups in the Hub. Parties enter the same Dungeon shard together.
- **Secure Trading:** Trade window in the Hub allowing players to swap items without dropping them on the ground.
- **Social Emotes:** Animations (Wave, Point, Cheer) integrated with the VOIP system for non-verbal cues.

## 3. Extraction Loop Refinement
Add tension and progression to the core gameplay.
- **Instance Collapse:** A timer for each Dungeon. If players fail to reach a Portal before time runs out, they are "consumed" by the dungeon (lose all gear).
- **Loot Rarity & Affixes:** Randomized item stats (e.g., "Rusty Sword of Might" with +2 STR).
- **Consumable System:** Implementation of healing potions, bandages, and food items with temporary buffs.

## 4. Advanced AI & PvE
Increase the challenge and variety of encounters.
- **Combat Archetypes:** Ranged enemies (skeletons), support/healers, and fast "assassin" mobs.
- **Boss Phase System:** Multi-stage encounters with unique arena hazards and transition triggers.
- **NPC Daily Life:** Simple schedules for Hub NPCs to make the village feel alive.

## 5. Technical Polish & Security
Ensure the game is fair, performant, and immersive.
- **Full Server-Authoritative Health:** Move `current_health` logic entirely to the Server. Clients only receive visual updates.
- **Persistent Progression:** Sync Level, XP, and Skill points to PocketBase.
- **Sensory Juice:**
    - **SFX:** Footsteps, sword clanks, ambient dungeon echoes.
    - **VFX:** Particle effects for hits, magic spells, and environment interaction.
    - **UI:** Improved HUD with animated health bars and cleaner inventory icons.
