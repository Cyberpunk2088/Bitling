extends Node

# ZIP packer (store only, no compression) for Godot
# Creates a ZIP archive containing the provided absolute file paths (read from disk).
# Note: This implements "store" (no compression) ZIP entries. Suitable for moderate frame counts.

class_name ZipPacker

# Build CRC32 table once
var _crc_table: PackedInt32Array = PackedInt32Array()
var _crc_table_initialized: bool = false

func _init():
	if not _crc_table_initialized:
		_generate_crc_table()

func _generate_crc_table() -> void:
	_crc_table = PackedInt32Array()
	_crc_table.resize(256)
	for i in 0:256:
		var c = i
		for j in 0:8:
			if (c & 1) != 0:
				c = 0xEDB88320 ^ (c >> 1)
			else:
				c = c >> 1
		_crc_table[i] = c
	_crc_table_initialized = true

func _crc32(data: PackedByteArray) -> int:
	var crc = 0xFFFFFFFF
	for b in data:
		crc = _crc_table[(crc ^ b) & 0xFF] ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF

func _uint_to_le_bytes(value: int, length: int) -> PackedByteArray:
	var out := PackedByteArray()
	for i in range(length):
		out.append(int((value >> (8 * i)) & 0xFF))
	return out

# Create a store-only ZIP archive (no compression)
# files: Array of absolute paths to include in the root of the archive
# out_path: absolute or user:// path to write ZIP
func create_zip(out_path: String, files: Array) -> bool:
	if files.empty():
		return false

	var fh = FileAccess.open(out_path, FileAccess.WRITE)
	if not fh:
		push_error("[ZipPacker] Cannot open output ZIP: " + out_path)
		return false

	var central_dir := []
	var offset = 0

	for fpath in files:
		var f = FileAccess.open(fpath, FileAccess.READ)
		if not f:
			push_warning("[ZipPacker] Cannot open file: " + fpath)
			continue
		var data = f.get_buffer(f.get_length())
		f.close()
		var filename = fpath.get_file()
		var crc = _crc32(data)
		var comp_size = data.size()
		var uncomp_size = data.size()

		# local file header
		var local := PackedByteArray()
		# signature
		local += _uint_to_le_bytes(0x04034b50, 4)
		# version needed (2 bytes)
		local += _uint_to_le_bytes(20, 2)
		# general purpose bit flag
		local += _uint_to_le_bytes(0, 2)
		# compression method (0 = store)
		local += _uint_to_le_bytes(0, 2)
		# mod time, mod date
		local += _uint_to_le_bytes(0, 2)
		local += _uint_to_le_bytes(0, 2)
		# crc32
		local += _uint_to_le_bytes(crc, 4)
		# comp size
		local += _uint_to_le_bytes(comp_size, 4)
		# uncomp size
		local += _uint_to_le_bytes(uncomp_size, 4)
		# filename length
		local += _uint_to_le_bytes(filename.length(), 2)
		# extra length
		local += _uint_to_le_bytes(0, 2)
		# filename bytes
		for c in filename.to_utf8():
			local.append(c)
		# write local header
		fh.store_8_array(local)
		# write file data
		fh.store_buffer(data)

		# remember central directory entry
		central_dir.append({"name":filename, "crc":crc, "comp_size":comp_size, "uncomp_size":uncomp_size, "offset":offset})
		# update offset: header + data
		offset += local.size() + data.size()

	# write central directory
	var central_start = offset
	for ent in central_dir:
		var c := PackedByteArray()
		# central file header signature
		c += _uint_to_le_bytes(0x02014b50, 4)
		# version made by
		c += _uint_to_le_bytes(20, 2)
		# version needed
		c += _uint_to_le_bytes(20, 2)
		# gp bit flag
		c += _uint_to_le_bytes(0, 2)
		# compression method
		c += _uint_to_le_bytes(0, 2)
		# mod time/date
		c += _uint_to_le_bytes(0, 2)
		c += _uint_to_le_bytes(0, 2)
		# crc32
		c += _uint_to_le_bytes(ent.crc, 4)
		# comp size
		c += _uint_to_le_bytes(ent.comp_size, 4)
		# uncomp size
		c += _uint_to_le_bytes(ent.uncomp_size, 4)
		# filename length
		c += _uint_to_le_bytes(ent.name.length(), 2)
		# extra length
		c += _uint_to_le_bytes(0, 2)
		# file comment length
		c += _uint_to_le_bytes(0, 2)
		# disk number start
		c += _uint_to_le_bytes(0, 2)
		# internal file attrs
		c += _uint_to_le_bytes(0, 2)
		# external file attrs
		c += _uint_to_le_bytes(0, 4)
		# relative offset of local header
		c += _uint_to_le_bytes(ent.offset, 4)
		# filename bytes
		for b in ent.name.to_utf8():
			c.append(b)
		fh.store_8_array(c)
		offset += c.size()

	var central_end = offset
	# End of central dir
	var eocd := PackedByteArray()
	# signature
	eocd += _uint_to_le_bytes(0x06054b50, 4)
	# disk numbers
	eocd += _uint_to_le_bytes(0, 2)
	eocd += _uint_to_le_bytes(0, 2)
	# total entries on this disk
	eocd += _uint_to_le_bytes(central_dir.size(), 2)
	# total entries
	eocd += _uint_to_le_bytes(central_dir.size(), 2)
	# size of central dir
	eocd += _uint_to_le_bytes(central_end - central_start, 4)
	# offset of start of central dir
	eocd += _uint_to_le_bytes(central_start, 4)
	# comment length
	eocd += _uint_to_le_bytes(0, 2)
	fh.store_8_array(eocd)
	fh.close()
	print("[ZipPacker] ZIP written to:", out_path)
	return true
