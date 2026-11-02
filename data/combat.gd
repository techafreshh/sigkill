class_name CombatTuning
extends RefCounted
## Data-only combat tuning: player survivability and contact damage numbers.
## No logic lives here; systems read these values (or matching literals).

const PLAYER := {
	"max_hp": 100.0,
	"contact_damage": 10.0,
	"iframes": 0.5,
	"contact_radius": 26.0,
}
