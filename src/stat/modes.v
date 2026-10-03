import os
import strings

// This file used to be called `stat_to_vlib.v`: it was a staging copy of the
// file mode helpers on their way into V's os module. The types have since
// landed in vlib/os, so it is no longer a copy of anything.
//
// It also used to import v.scanner/v.pref and decode --printf escapes with the
// V language scanner. Pulling the compiler into a coreutils binary made `v
// build` of this directory take minutes (it effectively hung), so the escape
// handling below is a plain hand-written decoder instead.

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

// raw_to_printf_string decodes the backslash escapes accepted by GNU stat's
// --printf. Example: r"\t[\x76]" becomes "	[v]".
//
// Recognised: \a \b \e \f \n \r \t \v \\ \" plus \NNN (1-3 octal digits) and
// \xHH (1-2 hex digits). Anything else is passed through as the escaped
// character, with a warning, which is what GNU does.
fn raw_to_printf_string(raw_string string) string {
	mut sb := strings.new_builder(raw_string.len)
	mut i := 0
	for i < raw_string.len {
		c := raw_string[i]
		if c != `\\` {
			sb.write_byte(c)
			i++
			continue
		}
		i++
		if i == raw_string.len {
			eprintln('stat: warning: backslash at end of format')
			sb.write_byte(`\\`)
			break
		}
		e := raw_string[i]
		i++
		match e {
			`a` { sb.write_byte(7) }
			`b` { sb.write_byte(8) }
			`e` { sb.write_byte(27) }
			`f` { sb.write_byte(12) }
			`n` { sb.write_byte(10) }
			`r` { sb.write_byte(13) }
			`t` { sb.write_byte(9) }
			`v` { sb.write_byte(11) }
			`\\` { sb.write_byte(`\\`) }
			`"` { sb.write_byte(`"`) }
			`0`...`7` {
				// \NNN: up to three octal digits
				mut value := int(e - `0`)
				mut digits := 1
				for digits < 3 && i < raw_string.len && is_octal_digit(raw_string[i]) {
					value = value * 8 + int(raw_string[i] - `0`)
					i++
					digits++
				}
				sb.write_byte(u8(value))
			}
			`x` {
				// \xHH: up to two hex digits
				mut value := 0
				mut digits := 0
				for digits < 2 && i < raw_string.len {
					d := hex_digit_value(raw_string[i]) or { break }
					value = value * 16 + d
					i++
					digits++
				}
				if digits == 0 {
					eprintln("stat: warning: unrecognized escape '\\x'")
					sb.write_byte(`x`)
				} else {
					sb.write_byte(u8(value))
				}
			}
			else {
				eprintln("stat: warning: unrecognized escape '\\${e}'")
				sb.write_byte(e)
			}
		}
	}
	return sb.str()
}

fn is_octal_digit(c u8) bool {
	return c >= `0` && c <= `7`
}

fn hex_digit_value(c u8) !int {
	if c >= `0` && c <= `9` {
		return int(c - `0`)
	}
	if c >= `a` && c <= `f` {
		return int(c - `a`) + 10
	}
	if c >= `A` && c <= `F` {
		return int(c - `A`) + 10
	}
	return error('not a hex digit')
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
