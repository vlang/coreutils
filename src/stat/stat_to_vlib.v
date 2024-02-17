import os
import v.scanner
import v.pref

pub enum FileType {
	unknown
	regular
	directory
	character_device
	block_device
	fifo
	symbolic_link
	socket
	contiguous_data
	door
	multiplex_file
	network_file
	port
	whiteout
}

pub struct FileMode {
pub:
	typ    FileType
	owner  FilePermission
	group  FilePermission
	others FilePermission
}

pub struct FilePermission {
	os.FilePermission
pub:
	special bool // setuid for owner, setgid for group, sticky for others
}

pub enum FilePermissionGroup {
	unknown
	owner
	group
	world
}

@[inline]
fn if_str(cond bool, str_if_true string, str_if_false string) string {
	return if cond { str_if_true } else { str_if_false }
}

pub fn (perm FilePermission) owner_to_string() string {
	return if_str(perm.read, 'r', '-') + if_str(perm.write, 'w', '-') + if !perm.special {
		if_str(perm.execute, 'x', '-')
	} else {
		if_str(perm.execute, 's', 'S')
	}
}

pub fn (perm FilePermission) group_to_string() string {
	return if_str(perm.read, 'r', '-') + if_str(perm.write, 'w', '-') + if !perm.special {
		if_str(perm.execute, 'x', '-')
	} else {
		if_str(perm.execute, 's', 'S')
	}
}

pub fn (perm FilePermission) world_to_string() string {
	return if_str(perm.read, 'r', '-') + if_str(perm.write, 'w', '-') + if !perm.special {
		if_str(perm.execute, 'x', '-')
	} else {
		if_str(perm.execute, 't', 'T')
	}
}

fn filetype_to_letter(typ FileType) string {
	return match typ {
		.regular { '-' }
		.directory { 'd' }
		.symbolic_link { 'l' }
		.block_device { 'b' }
		.character_device { 'c' }
		.fifo { 'p' }
		.socket { 's' }
		.contiguous_data { 'C' }
		.door { 'D' }
		.multiplex_file { 'm' }
		.network_file { 'n' }
		.port { 'P' }
		.whiteout { 'w' }
		else { '?' }
	}
}

fn filetype_to_string(typ FileType) string {
	return match typ {
		.regular { 'regular file' }
		.directory { 'directory' }
		.symbolic_link { 'symbolic link' }
		.block_device { 'block special file' }
		.character_device { 'character special file' }
		.fifo { 'fifo' }
		.socket { 'socket' }
		.contiguous_data { 'contiguous data' }
		.door { 'door' }
		.multiplex_file { 'multiplexed special file' }
		.network_file { 'network special file' }
		.port { 'port' }
		.whiteout { 'whiteout' }
		else { 'weird file' }
	}
}

// raw_to_printf_string converts a raw string into a printf-able string
// example: r"\t[\x76]" => "\t[\x76]" = "	[v]"
fn raw_to_printf_string(raw_string string) string {
	mut sc := scanner.new_scanner("'${raw_string}'", .skip_comments, &pref.Preferences{})
	return sc.scan().lit.replace(r'\a', '\a').replace(r'\b', '\b').replace(r'\e', '\e').replace(r'\f',
		'\f').replace(r'\n', '\n').replace(r'\r', '\r').replace(r'\t', '\t').replace(r'\v',
		'\v').replace(r'\\', '\\').replace(r"\'", "'").replace(r'\"', '"').replace(r'\?',
		'\?')
}

fn filemode_to_string(mode u16) string {
	fm := get_mode2(mode)
	mut s := filetype_to_letter(fm.typ) + fm.owner.owner_to_string() + fm.group.group_to_string() +
		fm.others.world_to_string()
	return s
}

// realpath follows symlinks until it finds the real target or exceeds
// max_link_depth attempts
fn realpath(path string, max_link_depth int) string {
	mut p := path
	for i := 0; i < max_link_depth; i++ {
		if !os.is_link(p) {
			break
		}
		p = readlink(p) or { app.quit(message: 'cannot resolve link: ${p}') }
	}
	return p
}
