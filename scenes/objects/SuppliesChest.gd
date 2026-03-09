extends StaticBody3D

## SuppliesChest
## A simple interactable chest that gives starter items to the player.

@export var item_id: String = "lantern"
@export var quantity: int = 1

func interact(_player: Node3D) -> void:
	print("[SuppliesChest] Player interacted! Giving: ", item_id)
	InventoryManager.add_item(item_id, quantity)
	
	# Optional: Visual/Audio feedback
	# _play_open_animation()
