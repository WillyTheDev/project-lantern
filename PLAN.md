# Project Plan - Project Lantern

This plan outlines the iterative development phases for Project Lantern.

## Phase 1: Foundation & Network Loop (Iteration 1)
- **Objective:** Finalize multi-role networking architecture.
- **Key Tasks:**
    - Verify `NetworkManager` CLI arguments (`--hub`, `--dungeon`).
    - Implement smooth player movement synchronization.
    - Test VOIP proximity and spatial audio.
- **Completion Criteria:** Two clients can connect to the Hub, see each other move smoothly, and hear each other's proximity-based voice chat.

## Phase 2: The Hub & Social Loop - The Preparation Pillar (Iteration 2)
- **Objective:** Implement the "Supplies Chest" and persistent inventory via PocketBase.
- **Key Tasks:**
    - Create `InventoryManager` autoload.
    - Implement "Supplies Chest" interactable in Hub.
    - Save/Load inventory from PocketBase.
- **Completion Criteria:** Player takes a lantern from the chest, restarts the game, and still has the lantern.

## Phase 3: The Dungeon & Extraction Loop (Iteration 3)
- **Objective:** Establish the core Hub-to-Dungeon gameplay flow.
- **Key Tasks:**
    - Implement Portal logic for scene transitions.
    - Create a basic Dungeon level with rooms.
    - Add an "Extraction Zone" that returns the player to the Hub.
- **Completion Criteria:** Player travels from Hub to Dungeon and back via extraction.

## Phase 4: The Encounter & Risk Loop (Iteration 4)
- **Objective:** Implement loot and PvPvE interactions.
- **Key Tasks:**
    - Create a lootable item system.
    - Implement inventory that is lost upon death in the dungeon.
    - Add basic environmental hazards and simple player interaction logic.
- **Completion Criteria:** Player loots an item, survives the dungeon, and sees their prestige increase in the Hub.
