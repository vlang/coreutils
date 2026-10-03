import arrays
import os

// The reference sorts names by byte order. Measured on GNU ls 9.4 with a
// directory holding Apple, BANANA, ZZZ, _under, aPPle, apple and banana: it
// printed them in that same order, and LC_ALL=C, C.UTF-8 and en_US.UTF-8 all
// agreed. Folding case would have put _under second and ZZZ last. An earlier
// report that GNU sorts case-insensitively came from a case-insensitive
// filesystem, where Apple and apple cannot both exist.
fn cmp_by_name(a &Entry, b &Entry) int {
	return compare_strings(a.name, b.name)
}

fn sort(entries []Entry, options Options) []Entry {
	// The closure is given its type up front. V 0.5.2 does not give the arms of
	// a `match` of closures a type it can pass to sorted_with_compare: it looks
	// for a function named after the variable instead and reports Uint128.cmp,
	// which has nothing to do with this module.
	mut entry_cmp := cmp_by_name
	if options.sort_size {
		entry_cmp = fn (a &Entry, b &Entry) int {
			return match true {
				// vfmt off
				a.size < b.size { 1 }
				a.size > b.size { -1 }
				else 		{ cmp_by_name(a, b) }
				// vfmt on
			}
		}
	} else if options.sort_time {
		entry_cmp = fn (a &Entry, b &Entry) int {
			return match true {
				// vfmt off
				a.stat.mtime < b.stat.mtime { 1 }
				a.stat.mtime > b.stat.mtime { -1 }
				else 			    { cmp_by_name(a, b) }
				// vfmt on
			}
		}
	} else if options.sort_width {
		entry_cmp = fn (a &Entry, b &Entry) int {
			a_len := a.name.len + a.link_origin.len + if a.link_origin.len > 0 { 4 } else { 0 }
			b_len := b.name.len + b.link_origin.len + if b.link_origin.len > 0 { 4 } else { 0 }
			result := a_len - b_len
			return if result != 0 { result } else { cmp_by_name(a, b) }
		}
	} else if options.sort_natural {
		entry_cmp = fn (a &Entry, b &Entry) int {
			return natural_compare(a.name, b.name)
		}
	} else if options.sort_ext {
		entry_cmp = fn (a &Entry, b &Entry) int {
			result := compare_strings(os.file_ext(a.name), os.file_ext(b.name))
			return if result != 0 { result } else { cmp_by_name(a, b) }
		}
	} else if options.sort_none {
		entry_cmp = fn (a &Entry, b &Entry) int {
			return 0
		}
	}

	// if directories first option, group entries into dirs and files
	// The 'dir' and 'file' labels are discriptive. The only thing that
	// matters is that the 'dir' key collates before the 'file' key
	groups := arrays.group_by[string, Entry](entries, fn [options] (e Entry) string {
		return if options.dirs_first && e.dir { 'dir' } else { 'file' }
	})

	mut sorted := []Entry{}
	for key in groups.keys().sorted() {
		sorted << groups[key].sorted_with_compare(entry_cmp)
	}

	return if options.sort_reverse { sorted.reverse() } else { sorted }
}
