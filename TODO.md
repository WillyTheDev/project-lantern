# Project Lantern Development Roadmap

## ✅ Iteration 1: Foundations (Infrastructure) - COMPLETED
## ✅ Iteration 2: The Hub & Social Loop - COMPLETED
## ✅ Iteration 3: Combat & The Vertical Slice - COMPLETED
- [x] **Vitality & Stats System**
- [x] **The Extraction Pillar (Dungeon-Hub Loop)**
- [x] **Server-Authoritative Interaction (Security Refactor)**
- [x] **Dungeon Guardian AI**
- [x] **Drag-and-Drop Loot System**
- [x] **Floating Damage Indicators & Hit FX**

## 🚧 Iteration 4: Procedural Extraction & Hardening
- [ ] **Procedural Dungeon Generation**
    - [ ] Implement a room-based generator for unique layouts.
    - [ ] Create multiple room templates (Agility, Combat, Reward).
- [ ] **Consumables & Combat Polish**
    - [ ] Implement Healing Potions.
    - [ ] Add attack animations and sword swing trails.
    - [ ] Add Guardian SFX and visual death particles.
- [ ] **Server Hardening (Tech Debt)**
    - [ ] Refactor Server `InventoryManager` to use Player Sessions.
    - [ ] Implement distance validation for all loot interactions.
- [ ] **Extraction Refinement**
    - [ ] Add "Extraction Timer" (Hold E to extract).
    - [ ] Penalty for Death: Lose un-extracted dungeon items.

## Verification Checklist
- [x] Survive combat with the Dungeon Guardian.
- [x] Successfully drag loot from a defeated enemy into inventory.
- [x] Extract via portal and verify items persisted in the Hub.
