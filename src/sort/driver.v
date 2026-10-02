// The comparison the whole program is built on. It applies each key definition in
// turn, and when they all call the lines equal it falls back on comparing the lines
// themselves, which is the last-resort comparison that -s turns off.
struct Comparator {
	options Options
	keys    []SortKey
}

// compare returns how a should be ordered against b.
fn (c &Comparator) compare(a &InputLine, b &InputLine) int {
	mut result := compare_keys(c.options, c.keys, a, b)
	if result != 0 {
		return result
	}
	if !c.options.ordering.stable {
		if c.options.ordering.reverse {
			result = compare_bytes(b.text, a.text)
		} else {
			result = compare_bytes(a.text, b.text)
		}
		if result != 0 {
			return result
		}
	}
	// Lines that weigh the same keep the order they arrived in, which is what -s
	// asks for and what -u relies on to decide which line of a run it keeps.
	return compare_values(f64(a.order), f64(b.order))
}

fn make_comparator(options Options, keys []SortKey) &Comparator {
	return &Comparator{
		options: options
		keys:    keys
	}
}

// compare_keys compares two lines by their keys alone, without the last-resort
// step. A zero result means the keys are equal.
//
// With no -k at all the whole line is the key, and the ordering options given on
// the command line are what weigh it.
fn compare_keys(options Options, keys []SortKey, a &InputLine, b &InputLine) int {
	if keys.len == 0 {
		return compare_key(&options.ordering, &a.text, &b.text)
	}
	for key in keys {
		ak := extract_key(a.text, &key, options.separator, options.has_separator,
			options.ordering.ignore_blanks)
		bk := extract_key(b.text, &key, options.separator, options.has_separator,
			options.ordering.ignore_blanks)
		result := compare_key(&key.ordering, &ak, &bk)
		if result != 0 {
			return result
		}
	}
	return 0
}

// sort_lines orders the whole input. Without -s the comparison is total, because
// of the last-resort step, so a plain sort is enough.
fn sort_lines(lines []InputLine, options Options, keys []SortKey) []InputLine {
	cmp := make_comparator(sort_options(options), keys)
	mut out := lines.clone()
	out.sort_with_compare(fn [cmp] (a &InputLine, b &InputLine) int {
		return cmp.compare(a, b)
	})
	return out
}

// unique_lines keeps the first line of every run that compares equal, which is
// what -u means: the lines may differ, the keys may not.
fn unique_lines(lines []InputLine, options Options, keys []SortKey) []InputLine {
	if !options.unique {
		return lines
	}
	mut out := []InputLine{}
	for line in lines {
		if out.len > 0 {
			previous := out[out.len - 1]
			// Only the keys count here. -s is deliberately not consulted: a run of
			// equal keys is a run of equal keys however the lines were ordered.
			if compare_keys(options, keys, &previous, &line) == 0 {
				continue
			}
		}
		out << line
	}
	return out
}

// check_input reports the first line that is out of order, the way GNU's -c does.
fn check_input(lines []InputLine, options Options, keys []SortKey) {
	cmp := make_comparator(options, keys)
	mut i := 1
	for i < lines.len {
		previous := lines[i - 1]
		current := lines[i]
		result := cmp.compare(&previous, &current)
		// The comparison breaks a tie by the order the lines arrived in, so a
		// non-zero result here means the later line weighs less than the earlier
		// one, which is a disorder. With -u a line whose key equals the one before
		// it is a disorder as well.
		equal_keys := compare_keys(options, keys, &previous, &current) == 0
		disordered := result > 0 || (options.unique && equal_keys)
		if disordered {
			if options.check == .diagnose {
				println('${app_name}: ${current.file}:${current.number}: disorder: ${current.text}')
			}
			exit(1)
		}
		i++
	}
}

// merge_input combines already sorted inputs the way -m does. The promise of -m is
// that each input is sorted, so the lines are merged without being sorted again,
// and a line that is out of place in its own file stays where it was.
fn merge_input(streams [][]InputLine, options Options, keys []SortKey) []InputLine {
	cmp := make_comparator(options, keys)
	mut out := []InputLine{}
	mut pos := []int{len: streams.len, init: 0}

	for {
		// Find the stream whose next line weighs least. When the lines weigh the
		// same the earlier stream wins, which is the order GNU merges in.
		mut best := -1
		for i, stream in streams {
			if pos[i] >= stream.len {
				continue
			}
			if best < 0 {
				best = i
				continue
			}
			chosen := cmp.compare(stream[pos[i]], streams[best][pos[best]])
			if chosen < 0 {
				best = i
			}
		}
		if best < 0 {
			break
		}
		out << streams[best][pos[best]]
		pos[best]++
	}
	return out
}
