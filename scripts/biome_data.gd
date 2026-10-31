class_name BiomeData
extends Resource
## A map's climate, saved as a .tres in resources/biomes/. Enemies swap to their variant for it.

@export var id: StringName = &""
@export var name_key: String = ""
## Weather for stormy missions here (blizzard, sandstorm). Empty = the mood's own weather (rain).
@export var storm_weather: PackedScene
