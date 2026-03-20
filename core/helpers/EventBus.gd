extends Node

## EventBus (Autoload)
## Central highway for all game-wide events to decouple systems and UI.

# ==========================================
# Authentication & Session Events
# ==========================================
signal auth_failed(reason: String)
signal session_started(user_data: Dictionary)
signal session_ended

# ==========================================
# Inventory & Stats Events
# ==========================================
signal inventory_updated
signal active_slot_changed(index: int)
signal stats_updated(stats: PlayerStatsData)
signal total_stats_updated(total_stats: Dictionary)
signal stash_updated
signal external_inventory_updated
signal stash_opened(is_open: bool)
