# 📉 Technical Debt Tracking

This document tracks known architectural shortcuts, security vulnerabilities, and "quick fixes" that need to be addressed in future iterations to ensure project scalability and security.

## 🛠 Active Technical Debt

### 1. Client-Authoritative Player Health
- **Added:** Iteration 3
- **Current State:** The player node is owned by the Client (`set_multiplayer_authority(player_id)`). The `MultiplayerSynchronizer` syncs `current_health` from the Client to the Server.
- **Shortcut:** Damage is detected on the Server but applied via an RPC to the Client, which then syncs it back.
- **Risk:** **Security Vulnerability.** A malicious client could modify their local memory to freeze their health at 100%, effectively making themselves invincible (God Mode).
- **Required Fix:** Refactor player authority. Separate movement authority (Client) from state authority (Server). Use a server-side `HealthComponent` that syncs down to the client.

### 2. Client-Authoritative Inventory Additions (Partially Addressed)
- **Added:** Iteration 2
- **Current State:** Clients currently tell the server "I added an item to my inventory" via `PBHelper.request_sync_inventory`.
- **Shortcut:** Simplifies the "Gameplay Loop" implementation for testing.
- **Risk:** **Security Vulnerability.** Clients can "spawn" any item they want by sending a spoofed sync request.
- **Required Fix:** Move all interaction and loot generation logic to the Server. The Client should only send "Interaction Requests," and the Server should execute the change and update PocketBase directly.

### 3. Hardcoded Local Server Addresses
- **Added:** Iteration 1
- **Current State:** `NetworkManager.server_address` defaults to `127.0.0.1`.
- **Shortcut:** Makes local testing easy.
- **Risk:** **Configuration Rigidity.** Switching shards in a production Kubernetes environment will fail unless environment variables or DNS discovery are properly integrated.
- **Required Fix:** Implement a dynamic service discovery or use K8s environment variables to provide the internal cluster IPs for the Hub and Dungeon shards.

### 4. Global Inventory Singleton on Server
- **Added:** Iteration 3
- **Current State:** The `InventoryManager` is a global singleton on the Server.
- **Shortcut:** The server uses one "global" memory for inventory logic.
- **Risk:** **Data Corruption / Race Condition.** If multiple players interact with inventories simultaneously, the server might overwrite one player's data with another's before saving to the database.
- **Required Fix:** Refactor the server-side `InventoryManager` to store player data in a `Dictionary` keyed by `peer_id` (Player Sessions), ensuring isolated state for every connected client.

---

## ✅ Resolved Debt
- **PocketBase Authentication:** Initial "guest" login was replaced by a secure **JWT Token Handoff** model in Iteration 3 refactor.
