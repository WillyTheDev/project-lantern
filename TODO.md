# TODO - Iteration 2: The Hub & Social Loop (The Preparation Pillar)

## Tasks
- [x] **PocketBase Integration**
    - [x] Create a `PersistenceManager` autoload with REST helper methods.
    - [x] Implement `login(username)` to get or create player records.
- [x] **Inventory System**
    - [x] Create an `InventoryManager` autoload to manage local items and sync with DB.
    - [x] Link `InventoryManager` to `PersistenceManager` for automatic PATCH updates.
- [x] **Interaction System**
    - [x] Add `interact` action to Input Map.
    - [x] Add `RayCast3D` based interaction to `player_controller.gd`.
    - [x] Create `SuppliesChest` interactable object.
- [x] **UI & Login**
    - [x] Add `UsernameInput` to Main Menu.
    - [x] Implement login flow: Login -> Connect -> Load Hub.
- [x] **Hub Integration**
    - [x] Place `SuppliesChest` in `Hub.tscn`.

## Verification
- [ ] Connect to Hub with username "TestPlayer".
- [ ] Interact with the Supplies Chest.
- [ ] Verify console log: "[InventoryManager] Successfully synced inventory to DB."
- [ ] Restart and verify inventory loads automatically.
