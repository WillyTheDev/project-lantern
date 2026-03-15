# Inventory Persistence & Synchronization

This document explains the technical flow of inventory data in Project Lantern to prevent regressions in the synchronization logic.

## 🏗️ The 3-State Model

Inventory exists in three places simultaneously:
1.  **PocketBase (Source of Truth):** The JSON representation in the `players` collection.
2.  **Server Node (Authority):** The `InventoryData` resources on the server-side player nodes.
3.  **Client Node (Visual):** The `InventoryData` resources on the client-side player nodes.

---

## 🔄 Synchronization Flow

### 1. Initialization (Login/Spawn)
1.  **Server:** Loads JSON from PocketBase.
2.  **Server:** Populates local `InventoryData` resources.
3.  **Client:** Reaches `_ready()` and sends `server_request_inventory_sync`.
4.  **Server:** Receives handshake and sends targeted `rpc_id` to that client + broadcast to others.

### 2. Item Movement (Looting/Equipping)
1.  **Client:** UI predicts the move locally for responsiveness.
2.  **Client:** Sends `request_move_item` RPC to the Server.
3.  **Server:** Validates indices and performs the move on its authoritative resources.
    *   *Note: Uses `InventoryManager.move_item` for automatic ItemStack <-> Dictionary conversion.*
4.  **Server:** Triggers `_sync_and_emit`.
5.  **Server:** Performs a `PATCH` request to PocketBase.
6.  **Server:** Broadcasts the new state to all clients via `sync_inventory_to_clients`.

### 3. Scene Transitions (Persistence Guarantee)
1.  **Player:** Touches a Portal or Logs Out.
2.  **Server:** `_exit_tree()` is triggered on the Player node.
3.  **Server:** Executes a final `_sync_and_emit` to ensure the very last state is saved to PocketBase before the node is destroyed.

---

## ⚠️ Critical Rules (Do Not Break)

1.  **Never Sync on Load:** Calling `_sync_and_emit` inside a loading function creates an infinite loop with the database.
2.  **NodePath over Strings:** Always use `NodePath` for external containers to ensure consistent identification across the network.
3.  **Reference Integrity:** `_get_array_by_type` must return a **direct reference** to the array, not a duplicate/temporary copy, or changes will not persist.
4.  **Handshake Requirement:** The Server must never push inventory data to a client until the client has explicitly signaled it is ready (via handshake).
5.  **Multiplayer Status:** Always check `multiplayer.has_multiplayer_peer()` before calling RPCs to avoid crashes during disconnects or transitions.
