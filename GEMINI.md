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
- **Auth Proxy:** Clients send credentials to the Game Server via RPC; the server proxies the authentication to PocketBase.

### 2. Global Autoloads (Singletons)
- `NetworkManager`: Handles role parsing, secure server/client connections (DTLS).
- `PersistenceManager`: **Server-Only** REST interface for PocketBase.
- `PBHelper`: High-level API for the game. Handles RPC bridging and request queuing.
- `InventoryManager`: Manages slot-based inventory (Hotbar, Bag, Armor) and player stats.
- `ItemDB`: Central registry for all item definitions.
- `TLSHelper`: Manages generation and loading of TLS certificates.
- `SceneManager`: Manages scene transitions and post-load login requests.

### 3. Inventory & Stats
- **Minecraft-style Slots:** 10 Action Slots (Hotbar), 30 Bag Slots, 4 Armor Slots.
- **Stats System:** Agility (Crit), Strength (Damage), Intellect (Magic), Stamina (Health).
- **Persistence:** Inventory state is automatically synced to PocketBase on changes.
