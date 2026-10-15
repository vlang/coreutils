module install

import common
import os

pub struct Settings {
pub mut:
	mode       string = '755'
	mode_given bool
	dir_flag   bool // -D: create leading directories
	target_dir bool // -t: copy sources into a directory
	no_clobber bool // -C
	preserve   bool // -p
	verbose    bool // -v
	backup     bool // -b
	dir_mode   string
	compare    bool
	strip      bool
	group      bool
	owner      bool
	target     string
	operands   []string
}

// run performs the copy and returns 1 if anything failed.
pub fn run(set Settings) int {
	bits, ok := parse_mode(set.mode)
	if !ok {
		eprintln('install: invalid mode ‘${set.mode}’')
		return 1
	}
	mut dir_bits := u32(0o755)
	if set.dir_mode != '' {
		d, ok2 := parse_mode(set.dir_mode)
		if ok2 {
			dir_bits = d
		}
	}

	mut sources := []string{}
	mut dest := ''
	if set.target_dir {
		// install -t DIR SOURCES... : the directory came from the -t option
		// itself, so every operand is a source.
		if set.target == '' {
			common.exit_with_error_message('install', 'missing file operand')
		}
		sources = set.operands.clone()
		dest = set.target
	} else if set.operands.len < 2 {
		if set.operands.len == 1 {
			common.exit_with_error_message('install', "missing destination file operand after '${set.operands[0]}'")
		}
		common.exit_with_error_message('install', 'missing file operand')
	} else {
		last := set.operands.len - 1
		sources = set.operands[..last].clone()
		dest = set.operands[last]
	}

	// More than one source is only meaningful into a directory, which is
	// what -t asks for; GNU also accepts an existing directory as the last
	// operand.
	if sources.len > 1 && !set.target_dir && !os.is_dir(dest) {
		common.exit_with_error_message('install', 'extra operand ${sources[1]}')
	}

	mut failed := 0
	for src in sources {
		mut target := dest
		if set.target_dir || os.is_dir(dest) {
			name := os.base(src)
			target = os.join_path(dest, name)
		}
		if set.dir_flag {
			parent := os.dir(target)
			mkdir_all(parent) or {
				eprintln('install: cannot create directory ${parent}')
				failed++
				continue
			}
			set_mode(parent, dir_bits)
		}
		// -C leaves an existing destination alone rather than overwriting.
		if set.no_clobber && os.exists(target) {
			continue
		}
		if set.backup && os.exists(target) {
			rename(target, '${target}~') or {}
		}
		if set.verbose && os.exists(target) {
			eprintln("removed '${target}'")
		}
		copy_file(src, target) or {
			eprintln("install: cannot stat '${src}': No such file or directory")
			failed++
			continue
		}

		set_mode(target, bits)
		if set.verbose {
			eprintln("'${src}' -> '${target}'")
		}
	}
	return if failed > 0 { 1 } else { 0 }
}

fn mkdir_all(path string) ? {
	if path == '' {
		return
	}
	os.mkdir_all(path) or { return none }
}

fn set_mode(path string, bits u32) {
	os.chmod(path, int(bits)) or {}
}

fn rename(from string, to string) ? {
	os.mv(from, to) or { return none }
}

fn copy_file(src string, dst string) ? {
	if !os.exists(src) {
		return none
	}
	data := read_source(src)
	mut f := os.create(dst) or { return none }
	f.write(data) or {
		f.close()
		return none
	}
	f.close()
}

// read_source is a one-line wrapper so the array-returning call sits at the
// top level of a function, where codegen handles it.
fn read_source(path string) []u8 {
	return os.read_file_array(path)
}

// parse_mode accepts an octal mode such as 640 or 755, and reports failure for
// anything GNU would reject.
pub fn parse_mode(spec string) (u32, bool) {
	if spec.len < 1 || spec.len > 4 {
		return 0, false
	}
	mut n := u32(0)
	for c in spec.bytes() {
		if c < `0` || c > `7` {
			return 0, false
		}
		n = n * 8 + u32(c - `0`)
	}
	return n & 0o7777, true
}
