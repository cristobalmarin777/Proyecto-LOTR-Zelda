class_name WeaponCatalog
extends RefCounted

## El catálogo vive separado del jugador para que cofres, vendedores y recompensas
## puedan consultar exactamente los mismos requisitos y valores de combate.
const WEAPONS := {
	"traveler_dagger": {
		"name": "Daga del Viajero", "damage": 1, "required_level": 1,
		"description": "Arma humilde pero fiable para iniciar el viaje.", "price": 0,
	},
	"barrow_blade": {
		"name": "Hoja de los Túmulos", "damage": 2, "required_level": 2,
		"description": "Una hoja antigua recuperada de las Quebradas de los Túmulos.", "price": 35,
	},
	"sting": {
		"name": "Dardo de Frodo", "damage": 3, "required_level": 3,
		"description": "Brilla y amplía la luz cuando hay orcos cerca.", "price": 70,
		"glows_near_orcs": true,
	},
	"ranger_sword": {
		"name": "Espada del Montaraz", "damage": 4, "required_level": 5,
		"description": "Equilibrada para los caminos largos de Eriador.", "price": 125,
	},
	"orcrist": {
		"name": "Orcrist, Hiendeorcos", "damage": 5, "required_level": 7,
		"description": "Hoja élfica pensada para las hordas de la oscuridad.", "price": 190,
	},
	"isildur_sword": {
		"name": "Espada de Isildur", "damage": 6, "required_level": 9,
		"description": "Reliquia de los Dúnedain, pesada de historia y voluntad.", "price": 280,
	},
	"glamdring": {
		"name": "Glamdring", "damage": 7, "required_level": 11,
		"description": "La Foe-hammer, espada élfica digna de un mago gris.", "price": 390,
	},
	"anduril": {
		"name": "Andúril, Llama del Oeste", "damage": 9, "required_level": 14,
		"description": "La espada culminante: poder a cambio de experiencia.", "price": 560,
	},
}

const ARMORS := {
	"traveler_cloak": {
		"name": "Capa de Viajero", "defense": 0, "required_level": 1,
		"description": "Ropas sencillas sin protección real.", "price": 0,
	},
	"shire_leather": {
		"name": "Cuero de la Comarca", "defense": 1, "required_level": 2,
		"description": "Cuero reforzado por artesanos hobbits.", "price": 45,
	},
	"elven_cloak": {
		"name": "Capa Élfica de Lórien", "defense": 2, "required_level": 4,
		"description": "Ligera, silenciosa y protectora.", "price": 105,
	},
	"dunedain_mail": {
		"name": "Malla de los Dúnedain", "defense": 3, "required_level": 7,
		"description": "Anillos de acero para caminos peligrosos.", "price": 205,
	},
	"mithril_coat": {
		"name": "Cota de Mithril", "defense": 4, "required_level": 10,
		"description": "Una defensa extraordinaria que debe recargarse tras bloquear.", "price": 360,
	},
}

static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS.traveler_dagger).duplicate(true)

static func armor(id: String) -> Dictionary:
	return ARMORS.get(id, ARMORS.traveler_cloak).duplicate(true)

static func weapon_ids() -> Array:
	return WEAPONS.keys()

static func armor_ids() -> Array:
	return ARMORS.keys()

