# Shard Transitions & Token Handoff

This document describes the technical process of moving a player between different server shards (e.g., from the Hub to a Dungeon) in Project Lantern.

## The Problem: Isolated Shards
Each shard (Hub Server, Dungeon Server) is an independent Godot process. They do not share memory or session state. To maintain security, a new shard must verify a player's identity before spawning them or loading their persistent data.

## The Solution: JWT Token Handoff
Instead of requiring the player to re-enter their password or sending sensitive credentials over the network during every transition, Project Lantern uses a **Token Handoff** model based on PocketBase JWTs.

### 1. Initial Authentication (Main Menu)
1.  The client sends `username` and `password` to the **Hub Server** via RPC.
2.  The Hub Server authenticates with PocketBase.
3.  On success, PocketBase returns a **JWT Session Token**.
4.  The Hub Server relays this token back to the client.
5.  The client caches this token in `SceneManager.cached_token`.

### 2. Shard Transition (Portal)
1.  The player enters a `Portal` area.
2.  The **Source Server** detects the collision and identifies the player's `peer_id`.
3.  The Source Server sends an RPC `_request_client_switch` to that specific client, providing the target server's `address`, `port`, and `scene_path`.
4.  The client:
    -   Sets `SceneManager.is_switching_shard = true`.
    -   Initiates an **Asynchronous Threaded Load** of the new scene.
    -   Disconnects from the current server and connects to the **Target Server**.

### 3. Re-Authentication (Target Server)
1.  Upon successful connection to the Target Server, `NetworkManager` detects `is_switching_shard`.
2.  The client sends the `cached_token` to the Target Server via `PBHelper.request_login_with_token`.
3.  The Target Server uses the token to call PocketBase's `auth-refresh` endpoint.
4.  PocketBase verifies the token and returns the user's record and a *new* refreshed token.
5.  The Target Server pulls the player's persistent data (inventory, stats) and spawns the player node.
6.  The Target Server sends the new refreshed token back to the client to keep the session alive.

## Visual Feedback: Enhanced Loading Screen
During this process, the `SceneManager` provides visual feedback via the `LoadingScreen`:
-   **Asynchronous Loading**: The scene is loaded in a background thread to prevent UI freezing.
-   **Progress Tracking**: `ResourceLoader.load_threaded_get_status` is used to update a `ProgressBar` in real-time.
-   **Smooth Transitions**: The loading screen uses `Tween` animations to fade in when starting and fade out gracefully once the player is spawned and the camera is active.

## Security Considerations
-   **Passwords** are only sent once during the initial login.
-   **Tokens** are short-lived and refreshed during every handoff.
-   **Server-Authoritative**: The client never tells the server "I am User X". Instead, it says "Here is my token, please ask PocketBase who I am."
