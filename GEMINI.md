## Project Overview
**Project Lantern** is a 3D stylized **Social-Extraction Crawler (PvPvE non-shooter)** built with **Godot 4.x**. The project features a persistent multiplayer world split into two main environments: a peaceful community **Hub** (The Village) and procedural **Dungeon** instances for exploration and loot.

### Key Technologies
- **Game Engine:** Godot 4.x (using Jolt Physics and Forward Plus renderer).
- **Networking:** Godot's ENet-based high-level multiplayer (UDP) with **DTLS Encryption**.
- **Architecture:** Multi-role binary (same image/build for client and servers).
- **Persistence:** **PocketBase** (Server-authoritative proxy model).
- **Infrastructure:** Docker and Kubernetes (K8s) with Cert-Manager for TLS.

## 🏗️ 3-Tier Core Architecture
Project Lantern follows a strict **3-Tier Separation of Concerns** for its core logic. All code in `core/` must adhere to these patterns. (See [ARCH_3_TIER.md](docs/ARCH_3_TIER.md) for details).

### 1. Service Tier (Facade / Public API)
- **Implementation**: Godot Autoloads (Singletons).
- **Role**: High-level API for UI and Gameplay. The "What".
- **Naming**: Suffix `Service` (e.g., `SessionService`, `InventoryService`).
- **Rule**: UI and Player scripts *only* call Services.

### 2. Manager Tier (Stateless Logic / Implementation)
- **Implementation**: Stateless Static Classes or Internal Nodes.
- **Role**: Logic, validation, and backend implementation. The "How".
- **Naming**: Suffix `Manager` (e.g., `InventoryManager`, `PocketBaseRPCManager`).
- **Rule**: Managers are called by Services, never directly by UI.

### 3. State Tier (Data Objects)
- **Implementation**: Godot Resources (`.tres`).
- **Role**: Pure data containers.
- **Naming**: Suffix `Data` (e.g., `SessionData`, `InventoryData`, `ItemStackData`).
- **Rule**: Serializable for PocketBase sync.

---

## 🛠️ Core Systems & Autoloads

- **`SessionService`**: High-level facade for User Authentication. Coordinates login, logout, and global state reset via `SessionData`.
- **`InventoryService`**: High-level facade for all inventory operations. Coordinates logic via `InventoryManager` and syncing via `PocketBaseRPCManager`.
- **`ItemService`**: Central registry for all item definitions (`ItemData`).
- **`NetworkService`**: Handles role parsing and secure server/client connections (DTLS).
- **`SceneService`**: Manages threaded scene transitions, loading screens, and credential caching for shard handoffs.
- **`PocketBaseRPCManager`**: High-level RPC bridge. Handles token distribution and server-authoritative requests.
- **`PocketBaseRESTManager`**: **Server-Only** REST interface for PocketBase.
- **`TLSHelper`**: Utility for TLS certificates.

---

## 🔦 Gameplay Mechanics

### 1. Shard Transitions
- **Auth Handoff**: Clients authenticate once at the Hub. On shard transition (Hub -> Dungeon), `SceneService` uses the `SessionData.auth_token` to re-authenticate on the new server without requiring a password.
- **Symmetry**: Client and Server use the same scene transitions but with different roles.

### 2. Inventory & Stats
- **Minecraft-style Slots:** 10 Hotbar Slots, 30 Bag Slots, 4 Armor Slots.
- **Stats System:** Agility (Crit), Strength (Damage), Intellect (Magic), Stamina (Health).
- **Health System:** Dynamic Max HP (100 base + 10 per Stamina point above 10).
- **Persistence**: Inventory state is synced to PocketBase on every change via `InventoryService`.

### 3. Combat & AI
- **Server-Authoritative:** Hit detection, damage calculation, and loot spawning are handled entirely by the server.
- **Physics Combat:** Directional sword attacks based on synchronized camera-raycasting.
- **AI Behaviors:** Persistence-aware chasing/attacking (e.g., Dungeon Guardian).
