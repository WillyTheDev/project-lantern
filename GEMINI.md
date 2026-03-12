## Project Overview
**Project Lantern** is a 3D stylized **Social-Extraction Crawler (PvPvE non-shooter)** built with **Godot 4.x**. The project features a persistent multiplayer world split into two main environments: a peaceful community **Hub** (The Village) and procedural **Dungeon** instances for exploration and loot.

### Key Technologies
- **Game Engine:** Godot 4.x (using Jolt Physics and Forward Plus renderer).
- **Networking:** Godot's ENet-based high-level multiplayer (UDP) with **DTLS Encryption**.
- **Architecture:** Multi-role binary (same image/build for client and servers).
- **Persistence:** **PocketBase** (Server-authoritative proxy model).
- **Infrastructure:** Docker and Kubernetes (K8s) with Cert-Manager for TLS.

## Architecture & Core Systems

### 1. Security & Infrastructure
- **Server-Authoritative:** Only the Game Server communicates with PocketBase via a restricted **System Account** (Least Privilege).
- **Encryption:** All multiplayer traffic is encrypted using **DTLS**. Certificates are managed by `TLSHelper`.
- **Auth Proxy & Token Handoff:** Clients authenticate via RPC. On success, they receive a JWT **Session Token**. During shard transitions (Hub to Dungeon), the client sends this token to the new server for password-less re-authentication via PocketBase `auth-refresh`.

### 2. Global Autoloads (Singletons)
- `NetworkManager`: Handles role parsing, secure server/client connections (DTLS), and automatic token-based shard login.
- `PersistenceManager`: **Server-Only** REST interface for PocketBase. Supports password and token-based authentication.
- `PBHelper`: High-level API for the game. Handles RPC bridging, token distribution, and request queuing.
- `InventoryManager`: Manages slot-based inventory (Hotbar, Bag, Armor) and player stats.
- `ItemDB`: Central registry for all item definitions.
- `TLSHelper`: Manages generation and loading of TLS certificates.
- `SceneManager`: Manages asynchronous threaded scene transitions, loading screen progress, and credential caching.

### 3. Inventory & Stats
- **Minecraft-style Slots:** 10 Action Slots (Hotbar), 30 Bag Slots, 4 Armor Slots.
- **Stats System:** Agility (Crit), Strength (Damage), Intellect (Magic), Stamina (Health).
- **Health System:** Dynamic Max HP (100 base + 10 per Stamina point above 10).
- **Persistence:** Inventory state is automatically synced to PocketBase on changes.

### 4. Combat & AI
- **Server-Authoritative:** Hit detection, damage calculation, and loot spawning are handled entirely by the server.
- **Physics Combat:** Directional sword attacks based on synchronized camera-raycasting.
- **AI Behaviors:** Group-based player detection and persistence-aware chasing/attacking (e.g., Dungeon Guardian).
- **Loot Drops:** Physical container spawning on enemy death with drag-and-drop synchronization.
