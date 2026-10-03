import os
import crypto.md5
import crypto.sha1
import crypto.sha256
import crypto.sha512
import crypto.blake2b
import math

struct Entry {
	name        string
	dir_name    string
	stat        os.Stat
	link_stat   os.Stat
	dir         bool
	file        bool
	link        bool
	exe         bool
	fifo        bool
	block       bool
	socket      bool
	character   bool
	unknown     bool
	link_origin string
	size        u64
	allocated   u64
	size_ki     string
	size_kb     string
	checksum    string
	invalid     bool // lstat could not access
}

fn get_entries(files []string, options Options) ([]Entry, []string, int) {
	mut entries := []Entry{cap: 50}
	mut dirs := []string{}
	mut status := 0

	for file in files {
		if options.list_directory_itself {
			// -d lists the operand, not what is inside it. GNU shows `.` for a
			// bare `ls -d`, which is the name it was given.
			entries << make_entry(file, '', options)
			continue
		}
		if os.is_dir(file) {
			dir_files := os.ls(file) or {
				status = 2 // see help for meaning of exit codes
				eprintln(err)
				continue
			}
			// An empty directory still needs a section of its own, and a group
			// keyed by it, or `ls emptydir anotherdir` would lose its header.
			dirs << file
			entries << match options.all {
				true { dir_files.map(make_entry(it, file, options)) }
				else { dir_files.filter(!is_dot_file(it)).map(make_entry(it, file, options)) }
			}
		} else {
			if os.lstat(file) or { os.Stat{} }.mode == 0 {
				// GNU treats an operand it cannot reach as a serious problem:
				// nothing is listed for it and the exit status is 2.
				eprintln("${app_name}: cannot access '${file}': No such file or directory")
				status = 2
				continue
			}
			if options.all || !is_dot_file(file) {
				entries << make_entry(file, '', options)
			}
		}
	}
	return entries, dirs, status
}

// os.join_path is not usable here: it rewrites a backslash in a file name into
// a separator, so `./back\slash` becomes `./back/slash` and the entry then
// fails to stat. Measured, not assumed. A name cannot contain a slash, so
// joining on one is safe on POSIX and accepted on Windows too.
fn entry_path(dir_name string, name string) string {
	if dir_name == '' {
		return name
	}
	if dir_name.ends_with('/') {
		return dir_name + name
	}
	return dir_name + '/' + name
}

fn make_entry(file string, dir_name string, options Options) Entry {
	mut invalid := false
	path := entry_path(dir_name, file)

	stat := os.lstat(path) or {
		// println('${path} -> ${err.msg()}')
		invalid = true
		os.Stat{}
	}

	filetype := stat.get_filetype()
	is_link := filetype == .symbolic_link
	link_origin := if is_link { read_link(path) } else { '' }
	mut size := stat.size
	mut link_stat := os.Stat{}

	if is_link && options.long_format && !invalid {
		// os.stat follows the link. The link itself is still what the size
		// column reports, so only the styling reads this: a link to a
		// directory is coloured as one. GNU shows 12 for a link to
		// /nonexistent, which is the length of the target string.
		link_stat = os.stat(path) or { os.Stat{} }
	}

	is_dir := filetype == .directory
	is_fifo := filetype == .fifo
	is_block := filetype == .block_device
	is_socket := filetype == .socket
	is_character_device := filetype == .character_device
	is_unknown := filetype == .unknown
	is_exe := !is_dir && is_executable(stat)
	is_file := filetype == .regular
	// -p appends a slash to directories and -F marks the type. They overlap on a
	// directory and agree there. In the long listing -F marks everything except a
	// symlink: GNU puts `-> target` after one instead of `@`. An ordinary file
	// gets nothing at all, and `?` is for a type GNU cannot name.
	indicator := if is_dir && (options.dir_indicator || options.classify) {
		'/'
	} else if options.classify && !(options.long_format && is_link) {
		if is_link {
			'@'
		} else if is_socket {
			'='
		} else if is_fifo || is_block || is_character_device {
			'%'
		} else if is_exe {
			'*'
		} else if is_unknown {
			'?'
		} else {
			''
		}
	} else {
		''
	}

	return Entry{
		// vfmt off
		name: 		file + indicator
		dir_name: 	dir_name
		stat: 		stat
		link_stat: 	link_stat
		dir: 		is_dir
		file: 		is_file
		link: 		is_link
		exe: 		is_exe
		fifo: 		is_fifo
		block: 		is_block
		socket: 	is_socket
		character: 	is_character_device
		unknown: 	is_unknown
		link_origin: 	link_origin
		size: 		size
		allocated: 	allocated_size(path)
		size_ki: 	if options.size_ki { readable_size(size, true) } else { '' }
		size_kb: 	if options.size_kb { readable_size(size, false) } else { '' }
		checksum: 	if is_file { checksum(file, dir_name, options) } else { '' }
		invalid: 	invalid
		// vfmt on
	}
}

// GNU's -h divides by 1024 and uses an uppercase suffix, --si divides by 1000
// and uses a lowercase one. Neither prints a `b`, and a value below the base is
// printed as it stands rather than as 1.0K.
//
// The rounding is a ceiling, not to nearest: 2500 bytes prints as 2.5K, not
// 2.4K, and 10240 as 10K while 10241 is 11K. One decimal is kept below ten and
// dropped at or above it, so 4096 is 4.0K and 102400 is 100K. All 33 sizes
// sampled from the reference fit this, and no nearest-rounding rule does.
fn readable_size(size u64, si bool) string {
	base := if si { f64(1000) } else { f64(1024) }
	units := if si {
		['', 'k', 'm', 'g', 't', 'p', 'e', 'z', 'y']
	} else {
		['', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y']
	}
	mut sz := f64(size)
	for i, unit in units {
		if sz < base || i == units.len - 1 {
			if unit == '' {
				return size.str()
			}
			tenths := int(math.ceil(sz * 10))
			if tenths >= 100 {
				return '${int(math.ceil(sz))}${unit}'
			}
			return '${tenths / 10}.${tenths % 10}${unit}'
		}
		sz /= base
	}
	return size.str()
}

fn checksum(name string, dir_name string, options Options) string {
	if options.checksum == '' {
		return ''
	}
	file := entry_path(dir_name, name)
	bytes := os.read_bytes(file) or { return unknown }

	return match options.checksum {
		// vfmt off
		'md5'     { md5.sum(bytes).hex() }
		'sha1'    { sha1.sum(bytes).hex() }
		'sha224'  { sha256.sum224(bytes).hex() }
		'sha256'  { sha256.sum256(bytes).hex() }
		'sha512'  { sha512.sum512(bytes).hex() }
		'blake2b' { blake2b.sum256(bytes).hex() }
		else      { unknown }
		// vfmt on
	}
}

@[inline]
fn is_executable(stat os.Stat) bool {
	return stat.get_mode().bitmask() & 0b001001001 > 0
}

@[inline]
fn is_dot_file(file string) bool {
	return file.starts_with('.')
}
