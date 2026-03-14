# Architectural Decision Record: 3-Tier Core Architecture

## Status
**Approved / In-Progress** (March 2026)

## Context
Project Lantern's `core/` directory had become fragmented. Responsibilities were split between "Managers" (often mixed state and logic), "Helpers" (often mixed with API logic), and "Autoloads" (scattered across folders). This led to:
1. **State Leakage**: Hard to reset all systems correctly on logout/disconnect.
2. **Ambiguous Responsibilities**: Difficult to know where a specific piece of logic (e.g., inventory move) should live.
3. **Refactoring Friction**: High coupling between UI and low-level REST implementation.

## Decision
We are refactoring the `core/` directory into a **3-Tier Architecture** with a clear separation of concerns.

### 1. Service Tier (High-Level Facade / API)
- **Implementation**: Godot Autoloads (Singletons).
- **Responsibility**: The "What". Public API for UI and Gameplay scripts.
- **Rules**:
    - **No low-level logic**: It delegates to Managers.
    - **Owns Signals**: UI binds to these signals for updates.
    - **Symmetry**: Provides the same interface for both Client and Server where possible.
- **Examples**: `InventoryService`, `SessionService`, `NetworkService`.

### 2. Manager Tier (Stateless Logic / Implementation)
- **Implementation**: Static Classes or Internal Nodes.
- **Responsibility**: The "How". Pure logic, validation, and backend-specific implementation.
- **Rules**:
    - **Stateless**: Does not store data between calls.
    - **Deterministic**: Given the same Input State, it returns the same result.
    - **Backend-Specific**: Handles the actual REST/Socket complexity.
- **Examples**: `InventoryManager`, `PocketBaseManager`, `AuthLogic`.

### 3. State Tier (Data Objects)
- **Implementation**: Godot Resources (`.tres` / `class_name`).
- **Responsibility**: Pure Data.
- **Rules**:
    - **Minimal Logic**: Only basic getters/setters or `to_dict()`/`from_dict()` for serialization.
    - **Passed by Reference**: Allows Services to manipulate data and UI to observe it.
- **Examples**: `InventoryData`, `PlayerStatsData`, `SessionData`.

### 4. Helper Tier (Reusable Utilities)
- **Implementation**: Static Function Libraries.
- **Responsibility**: Cross-cutting utilities (String formatting, Encryption, etc.).
- **Examples**: `TLSHelper`, `StringUtils`.

## Naming Conventions
All scripts in the `core/` directory MUST follow these suffixes to ensure architectural clarity:

| Tier | Folder | Suffix | Example |
| :--- | :--- | :--- | :--- |
| **Service (Facade)** | `core/services/` | `Service` | `InventoryService.gd`, `SessionService.gd` |
| **Manager (Logic)** | `core/managers/` | `Manager` | `InventoryManager.gd`, `PocketBaseRPCManager.gd` |
| **State (Data)** | `core/state/` | `Data` | `InventoryData.gd`, `SessionData.gd` |
| **Helper (Utility)** | `core/helpers/` | `Helper` | `TLSHelper.gd`, `StringUtilsHelper.gd` |

## Autoload Configuration
Services and Managers should be configured as **Autoloads** in `project.godot`. When an Autoload is created, its **Class Name** should be removed from the script (`class_name ...`) to avoid parser conflicts between the static class type and the global singleton instance.

## Best Practices
- **UI Interaction**: UI scripts (`.gd`) should only ever call methods on **Services**. They should never touch a Manager or manipulate State resources directly.
- **Stateless Managers**: Managers should be static or stateless. They take a State object as an argument, modify it, and return the result.
- **Centralized Reset**: `SessionService.logout()` is the master switch. It is responsible for calling `.reset()` on all other services.
