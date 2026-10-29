class_name ResourceFolder
extends RefCounted
## Loads every .tres in a folder. Shared by the registries (materials, items...).


static func load_all(folder: String) -> Array[Resource]:
	var resources: Array[Resource] = []
	for file: String in DirAccess.get_files_at(folder):
		# Exported builds list "x.tres.remap" instead of "x.tres"; load() still works with "x.tres".
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var resource: Resource = load(folder.path_join(file))
			if resource:
				resources.append(resource)
	return resources
