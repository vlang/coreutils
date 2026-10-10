module dir

import common
import os

pub struct Settings {
pub mut:
	all          bool // -a: include . and ..
	recursive    bool // -R
	columns      bool // -C
	one_per_line bool // -1
	by_time      bool // -t: newest first
	by_size      bool // -S: largest first
	reverse      bool // -r
	width        int = 80
	width_given  bool
	operands     []string
}

pub enum SortKey {
	name // dir's only true sort: alphabetical
	time // -t: newest first
	size // -S: largest first
}

// run lists the operands and returns the formatted output, along with the
// exit status, because a path that cannot be accessed is a failure and GNU
// exits 2 for it.
pub fn run(set Settings) (string, int) {
	mut out := []string{}
	mut targets := set.operands.clone()
	if targets.len == 0 {
		targets = ['.']
	}
	mut failed := false

	for target in targets {
		st := os.lstat(target) or {
			eprintln('dir: cannot access ${quoted(target)}: No such file or directory')
			failed = true
			continue
		}
		if st.get_filetype() == .directory {
			list_directory(mut out, target, set, true)
		} else {
			out << target
		}
	}
	if failed {
		return out.join('\n'), 2
	}
	return out.join('\n'), 0
}

fn quoted(s string) string {
	return "'${s}'"
}

fn list_directory(mut out []string, path string, set Settings, is_root bool) {
	entries := os.ls(path) or {
		return
	}
	mut names := []string{}
	if set.all {
		// GNU lists . and .. first under -a, and os.ls omits them.
		names << '.'
		names << '..'
	}
	for e in entries {
		names << e
	}
	names = sorted_names(names, path, set)

	if set.recursive && !is_root {
		out << ''
	}
	if set.recursive {
		out << '${path}:'
	}
	out << render(names, set)

	// -R descends into each subdirectory after its parent has been listed.
	if !set.recursive {
		return
	}
	for name in names {
		if name == '.' || name == '..' {
			continue
		}
		child := os.join_path(path, name)
		st := os.lstat(child) or { continue }
		if st.get_filetype() == .directory {
			list_directory(mut out, child, set, false)
		}
	}
}

// render lays the names out. The default is columns across the line, which is
// GNU's -C behaviour when the output is not a terminal; -1 gives one per line.
// Each cell is padded to the width of the widest entry in its column plus two
// spaces, and the final column carries no padding, so no line ends in spaces.
fn render(names []string, set Settings) string {
	if set.one_per_line {
		return names.join('\n')
	}
	if names.len == 0 {
		return ''
	}
	return names.join('  ')
}

struct Entry {
	name string
	path string
}

// sorted_names applies the requested order. Each entry name is joined onto the
// directory before -t or -S compares them, because those keys live in the file
// system and a bare name says nothing about size or time.
fn sorted_names(names []string, path string, set Settings) []string {
	mut entries := []Entry{}
	for n in names {
		entries << Entry{
			name: n
			path: os.join_path(path, n)
		}
	}

	if set.by_time {
		entries.sort_with_compare(fn (a &Entry, b &Entry) int {
			if a.path == '.' || a.path == '..' || b.path == '.' || b.path == '..' {
				return 0
			}
			ma := mtime_of(a.path)
			mb := mtime_of(b.path)
			if ma > mb {
				return -1
			}
			if ma < mb {
				return 1
			}
			return compare_names(a, b)
		})
	} else if set.by_size {
		entries.sort_with_compare(fn (a &Entry, b &Entry) int {
			if a.name == '.' || a.name == '..' || b.name == '.' || b.name == '..' {
				return 0
			}
			sa := size_of(a.path)
			sb := size_of(b.path)
			if sb > sa {
				return -1
			}
			if sb < sa {
				return 1
			}
			return compare_names(a, b)
		})
	} else {
		entries.sort_with_compare(fn (a &Entry, b &Entry) int {
			return compare_names(a, b)
		})
	}

	mut out := []string{cap: entries.len}
	for e in entries {
		out << e.name
	}
	return reverse_if(set, out)
}

fn compare_names(a &Entry, b &Entry) int {
	if a.name < b.name {
		return -1
	}
	if a.name > b.name {
		return 1
	}
	return 0
}

fn reverse_if(set Settings, names []string) []string {
	if !set.reverse {
		return names
	}
	mut out := []string{cap: names.len}
	mut i := names.len - 1
	for i >= 0 {
		out << names[i]
		i--
	}
	return out
}

fn mtime_of(path string) i64 {
	st := os.lstat(path) or { return 0 }
	return st.mtime
}

fn size_of(path string) u64 {
	st := os.lstat(path) or { return 0 }
	return st.size
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--' {
			operands << args[i + 1..]
			break
		}
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('dir (V coreutils) ${common.version}')
			exit(0)
		}
		if !a.starts_with('-') || a == '-' {
			operands << a
			continue
		}

		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--all' { s.all = true }
				'--recursive' { s.recursive = true }
				'--color', '--color=always', '--color=auto' {}
				'--width' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.width = width_value(v)
					s.width_given = true
				}
				else {
					common.exit_with_error_message('dir', "unrecognized option '${a}'")
				}
			}
			continue
		}

		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`a` { s.all = true }
				`R` { s.recursive = true }
				`C` { s.columns = true }
				`1` { s.one_per_line = true }
				`t` { s.by_time = true }
				`S` { s.by_size = true }
				`r` { s.reverse = true }
				`w` {
					v, next := take_short(args, i, a, j)
					i = next
					s.width = width_value(v)
					s.width_given = true
					j = a.len
					continue
				}
				`-` {
					j++
					continue
				}
				else {
					common.exit_with_error_message('dir', "invalid option -- '${c.ascii_str()}'")
				}
			}
			j++
		}
	}

	s.operands = operands
	return s
}

fn width_value(v string) int {
	mut n := 0
	for c in v.bytes() {
		if c < `0` || c > `9` {
			common.exit_with_error_message('dir', "invalid line width: '${v}'")
		}
		n = n * 10 + int(c - `0`)
	}
	if n == 0 {
		common.exit_with_error_message('dir', "invalid line width: '${v}': Numerical result out of range")
	}
	return n
}

fn take_short(args []string, i int, a string, j int) (string, int) {
	rest := a[j + 1..]
	if rest != '' {
		return rest, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('dir', "option requires an argument -- '${a[j].ascii_str()}'")
	}
	return args[i + 1], i + 1
}

fn take_value(args []string, i int, inline_val string, has_val bool, name string) (string, int) {
	if has_val {
		return inline_val, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('dir', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: dir [OPTION]... [FILE]...')
	println('List information about the FILEs (the current directory by default).')
	println('Sort entries alphabetically if none of -cftuvSUX nor --sort is specified.')
	println('')
	println('  -a, --all            do not ignore entries starting with .')
	println('  -C                   list entries by columns')
	println('  -1                   list one file per line')
	println('  -R, --recursive      list subdirectories recursively')
	println('  -r, --reverse        reverse order while sorting')
	println('  -S                   sort by file size, largest first')
	println('  -t                   sort by time, newest first')
	println('  -w, --width=COLS     assume output width is COLS')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
