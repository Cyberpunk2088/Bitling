extends RefCounted
class_name ZipPacker

## Small wrapper around Godot's built-in ZIPPacker.
## Paths inside the archive are reduced to file names to avoid leaking device paths.

func create_zip(out_path: String, files: Array) -> bool:
	if out_path.is_empty() or files.is_empty():
		return false
	var packer := ZIPPacker.new()
	var open_error := packer.open(out_path)
	if open_error != OK:
		push_error("[ZipPacker] Could not open archive: %s" % open_error)
		return false

	var written := 0
	for value in files:
		var file_path := str(value)
		if not FileAccess.file_exists(file_path):
			continue
		var source := FileAccess.open(file_path, FileAccess.READ)
		if source == null:
			continue
		var data := source.get_buffer(source.get_length())
		source.close()
		var start_error := packer.start_file(file_path.get_file())
		if start_error != OK:
			continue
		var write_error := packer.write_file(data)
		packer.close_file()
		if write_error == OK:
			written += 1

	packer.close()
	if written == 0:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(out_path))
		return false
	return true
