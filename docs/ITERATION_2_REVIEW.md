# Iteration 2 Review: The Preparation Pillar

This document reviews the implementation of the persistence and inventory systems introduced in Iteration 2.

## 🏗️ Architectural Patterns

### 1. Singleton (Autoload) Pattern
- **PocketBaseRESTManager:** Centralized authority for PocketBase REST API calls. It handles the "dirty work" of HTTP requests, headers, and JSON parsing.
- **InventoryService:** Manages the local player's state. It acts as a middleman between game logic (taking an item) and persistence (saving to DB).
- **Benefit:** Provides a global, easy-to-access API for any scene or script to interact with player data.

### 2. "Interface" via Duck Typing (Interaction System)
- The Player's `RayCast3D` looks for any collider that has an `interact()` method.
- **Benefit:** Extremely decoupled. You can create a chest, a door, a NPC, or a lever; as long as they have an `interact()` function, the player can use them without the player script needing to know what they are.

### 3. Observer Pattern (Signals)
- `PocketBaseRESTManager` emits `request_completed`.
- `InventoryService` emits `inventory_updated`.
- **Benefit:** UI elements or other systems can "listen" for data changes without being tightly coupled to the managers.

---

## ✅ Good Practices Followed

- **Separation of Concerns:** 
    - Networking logic remains in `NetworkService`.
    - Data logic is in `PocketBaseRESTManager`.
    - Inventory logic is in `InventoryService`.
- **Asynchronous Design:** Used `await` and signals for HTTP requests to ensure the game doesn't freeze while waiting for the database.
- **Environment Awareness:** `PocketBaseRESTManager` checks for `POCKETBASE_URL` environment variables, making it "K8s-ready" out of the box.
- **Minimal Impact:** Integrated the interaction system into the existing `player_controller.gd` without breaking movement or VOIP logic.

---

## 🚀 Possible Improvements & Technical Debt

### 1. Security & Auth (✅ Addressed)
- **Status:** Refactored to use **JWT Token Handoff**.
- **Implementation:** PocketBase `auth-with-password` is used for initial login. A JWT session token is returned and cached. During shard transitions, the token is reused via `auth-refresh`, eliminating the need to send passwords between servers.

### 2. Validation (Multiplayer Security)
- **Current:** The client tells the server "I have a new item."
- **Improvement:** In a competitive environment, the *Server* should handle the interaction logic and update the database, then sync the result back to the client to prevent cheating.

### 3. Batching & Throttling
- **Current:** Every item added triggers a `PATCH` request.
- **Improvement:** Implement a "dirty" flag or a small delay (e.g., 1 second) before syncing to the DB to batch multiple rapid changes into a single request.

### 4. Robust Error Handling
- **Current:** Prints errors to the console.
- **Improvement:** Add a global "Notification" system to show the user "Connection lost" or "Failed to save inventory" via the UI.

### 5. Type Safety
- **Current:** Inventory is a `Dictionary`.
- **Improvement:** Define a `Resource` type for Items (e.g., `ItemData.gd`) to handle icons, descriptions, and stack sizes more cleanly.
