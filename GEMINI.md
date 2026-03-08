# 🔦 GEMINI.md - Project Lantern

## Project Overview
**Project Lantern** is a 3D stylized **Social-Extraction Crawler (PvPvE non-shooter)** built with **Godot 4.x**. The project features a persistent multiplayer world split into two main environments: a peaceful community **Hub** (The Village) and procedural **Dungeon** instances for exploration and loot.

### Key Technologies
- **Game Engine:** Godot 4.x (using Jolt Physics and Forward Plus renderer).
- **Networking:** Godot's ENet-based high-level multiplayer (UDP).
- **Architecture:** Multi-role binary (same image/build for client and servers).
- **Persistence:** **PocketBase** for player data and "Visual Prestige" grades.
- **Infrastructure:** Docker and Kubernetes (K8s) for server orchestration.

## Architecture & Core Systems

### 1. Multi-Role Workflow
The application uses CLI arguments to determine its role at startup:
- **Client:** Default role (starts at Main Menu).
- **Hub Server:** Started with `--hub` (starts at Hub scene, port 9797).
- **Dungeon Server:** Started with `--dungeon` (starts at Dungeon scene, port 9798).

### 2. Global Autoloads (Singletons)
- `NetworkManager` (`core/network/NetworkManager.gd`): Handles role parsing, server startup (Hub/Dungeon), and client connections.
- `SceneManager` (`core/scene_manager/SceneManager.gd`): Automatically loads the correct scene (`Hub.tscn`, `Dungeon.tscn`, or `MainMenu.tscn`) based on the active `NetworkManager` role.
- `VoiceManager` (`core/network/VoiceManager.gd`): Manages spatial VOIP, VAD (Voice Activity Detection), and Opus packet relay.

### 3. Networking & Sync
- **VOIP Implementation:** Uses the `two-voip-godot-4` GDExtension for Opus compression and RNNoise denoising.
- **VAD & Hang-Time:** Voice packets are only sent when volume exceeds a threshold (adjustable in Settings). A 0.8s "Hang-Time" ensures smooth transitions.
- **Spawning:** Managed by `MultiplayerSpawner` with custom spawn functions (`hub_mult_spawner.gd`) to handle peer-to-peer data initialization.
- **Synchronization:** Uses `MultiplayerSynchronizer` for player movement, position interpolation, and velocity sync.
- **Communication:** RPCs are used for discrete events like `sync_respawn`.

## Building and Running

### Local Development
- **Run Client:** `godot`
- **Run Hub Server (Headless):** `godot --headless -- --hub`
- **Run Dungeon Server (Headless):** `godot --headless -- --dungeon`

### Docker & Deployment
The project uses a multi-stage Dockerfile to export a Linux binary and run it in a minimal Ubuntu environment.
- **Build Image:** `docker build -t harbor.kube.dungeonmomo.cc/project-lantern/project-lantern:latest .`
- **Deploy to K8s:** `kubectl apply -f k8s/deployment.yaml` (Deploys PocketBase, Hub, and Dungeon in the `project-lantern` namespace).

## Development Conventions
- **Scene Structure:**
    - `core/`: Core engine logic and autoloads.
    - `scenes/actors/`: Entity logic (Players, etc.).
    - `scenes/levels/`: World scenes (Hub, Dungeon).
    - `ui/`: Interface elements.
- **Networking:** Always verify `is_multiplayer_authority()` before processing local input or physics in player-controlled nodes.
- **Style:** 3D stylized art, Jolt Physics for interactions, and non-combat focused progression (cosmetic/prestige).

## Key Files
- `project.godot`: Main configuration, Jolt physics setup, and autoloads.
- `core/network/NetworkManager.gd`: Role and port management.
- `scenes/actors/player/player_controller.gd`: Main movement and networking logic.
- `k8s/deployment.yaml`: Kubernetes infrastructure definition.
