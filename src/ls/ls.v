import arrays { group_by }
import datatypes { Set }
import os
import math

fn main() {
	options, files := get_args()
	set_auto_wrap(options)
	entries, status := get_entries(files, options)
	mut cyclic := Set[string]{}
	status1 := ls(entries, options, mut cyclic)
	exit(math.max(status, status1))
}

fn ls(entries []Entry, options Options, mut cyclic Set[string]) int {
	mut status := 0
	group_by_dirs := group_by[string, Entry](entries, fn (e Entry) string {
		return e.dir_name
	})
	sorted_dirs := group_by_dirs.keys().sorted()

	for dir in sorted_dirs {
		files := group_by_dirs[dir]
		filtered := filter(files, options)
		sorted := sort(filtered, options)
		if group_by_dirs.len > 1 || options.recursive {
			print_dir_name(dir, options)
		}
		print_files(sorted, options)

		if options.recursive {
			for entry in sorted {
				if entry.dir {
					entry_path := os.join_path(entry.dir_name, entry.name)
					if cyclic.exists(entry_path) {
						println('===> cyclic reference detected <===')
						continue
					}
					cyclic.add(entry_path)
					dir_entries, status1 := get_entries([entry_path], options)
					status2 := ls(dir_entries, options, mut cyclic)
					cyclic.remove(entry_path)
					status = math.max(status1, status2)
				}
			}
		}
	}
	return status
}
