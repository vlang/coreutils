import arrays { group_by }
import datatypes { Set }
import math

fn main() {
	options, files := get_args()
	set_auto_wrap(options)
	entries, dirs, status := get_entries(files, options)
	mut cyclic := Set[string]{}
	mut printed_any := false
	status1 := ls(entries, dirs, options, mut cyclic, &printed_any, '')
	exit(math.max(status, status1))
}

// section names the directory this call is listing, so that one holding nothing
// still gets its header. GNU prints `./Zdir:` above no rows at all rather than
// skipping it. dirs carries the directory operands so that an empty one still
// gets a section: it produces no entries, so grouping alone would lose it.
fn ls(entries []Entry, dirs []string, options Options, mut cyclic Set[string], printed_any &bool, section string) int {
	mut status := 0
	group_by_dirs := group_by[string, Entry](entries, fn (e Entry) string {
		return e.dir_name
	})
	mut sections := dirs.clone()
	for name in group_by_dirs.keys() {
		if !sections.contains(name) {
			sections << name
		}
	}
	sorted_dirs := sections.sorted()

	if sorted_dirs.len == 0 {
		// Nothing came back from the directory, but its header still has to be
		// printed and the long listing still has to say `total 0`.
		print_dir_name(section, options, printed_any)
		print_files([], options)
		return 0
	}

	for dir in sorted_dirs {
		files := group_by_dirs[dir]
		filtered := filter(files, options)
		sorted := sort(filtered, options)
		if sections.len > 1 || options.recursive {
			print_dir_name(dir, options, printed_any)
		}
		print_files(sorted, options)
		// A header that follows rows is still preceded by a blank line, even
		// when the rows came from an unnamed section such as a bare operand.
		if sorted.len > 0 {
			unsafe {
				*printed_any = true
			}
		}

		if options.recursive {
			for entry in sorted {
				if entry.dir {
					path := entry_path(entry.dir_name, entry.name)
					if cyclic.exists(path) {
						println('===> cyclic reference detected <===')
						continue
					}
					cyclic.add(path)
					dir_entries, sub_dirs, status1 := get_entries([path], options)
					status2 := ls(dir_entries, sub_dirs, options, mut cyclic, printed_any, path)
					cyclic.remove(path)
					status = math.max(status1, status2)
				}
			}
		}
	}
	return status
}
