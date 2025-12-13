import strconv

enum SortType {
	ascii
	numeric
	leading
	dictionary
	ignore_case
	ignore_non_printing
	reverse
}

struct SortKey {
	f1        int
	c1        int
	f2        int
	c2        int
	sort_type SortType
}

fn sort_key(mut lines []string, options Options) {
	mut sort_keys := []SortKey{}
	for sort_key in options.sort_keys {
		sort_keys << parse_sort_key(sort_key)
	}

	lines.sort_with_compare(fn [sort_keys, options] (a &string, b &string) int {
		for key in sort_keys {
			aa := find_field(a, key, options)
			bb := find_field(b, key, options)
			// println('${aa}, ${bb}')
			result := match key.sort_type {
				.numeric { compare_numeric(aa, bb) }
				.leading { compare_leading(aa, bb) }
				.dictionary { compare_dictionary(aa, bb) }
				.ignore_case { compare_ignore_case(aa, bb) }
				.ignore_non_printing { compare_ignore_non_printing(aa, bb) }
				.reverse { compare_strings(bb, aa) }
				else { compare_strings(aa, bb) }
			}
			if result != 0 {
				return result
			}
		}
		return compare_strings(a, b)
	})
}

fn compare_numeric(a &string, b &string) int {
	af, ar := numeric_rest(a)
	bf, br := numeric_rest(b)
	diff := af - bf
	return if diff != 0 {
		match diff > 0 {
			true { 1 }
			else { -1 }
		}
	} else {
		compare_strings(ar, br)
	}
}

fn compare_leading(a &string, b &string) int {
	aa := trim_leading_spaces(a)
	bb := trim_leading_spaces(b)
	return compare_strings(aa, bb)
}

fn compare_dictionary(a &string, b &string) int {
	aa := a.bytes().map(is_dictionary_char).bytestr()
	bb := b.bytes().map(is_dictionary_char).bytestr()
	return compare_strings(aa, bb)
}

fn compare_ignore_case(a &string, b &string) int {
	return compare_strings(a.to_upper(), b.to_upper())
}

fn compare_ignore_non_printing(a &string, b &string) int {
	aa := a.bytes().map(is_printable).bytestr()
	bb := b.bytes().map(is_printable).bytestr()
	return compare_strings(aa, bb)
}

fn find_field(s string, key SortKey, options Options) string {
	parts := s.split(options.field_separator)
	f1 := key.f1 - 1
	c1 := if key.c1 > 0 { key.c1 - 1 } else { 0 }
	f2 := key.f2 // from the end, don't subtrace 1
	c2 := key.c2 // from the end, don't subtrace 1
	start := if f1 < parts.len { f1 } else { 0 }
	end := if f2 >= f1 && f2 < parts.len { f2 } else { parts.len }
	join := parts[start..end].join('')
	begin := join[c1..]
	field := if c2 > 0 {
		c := begin.len - c2
		begin[..c]
	} else {
		begin
	}
	return field
}

fn parse_sort_key(k string) SortKey {
	mut i := 0
	mut f1 := 0
	mut c1 := 0
	mut f2 := 0
	mut c2 := 0
	mut start := 0

	// field
	for ; i < k.len; i++ {
		if !k[i].is_digit() {
			f1 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
			break
		}
	}

	if f1 == 0 {
		f1 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
	}

	// column
	if i < k.len && k[i] == `.` {
		i += 1
		start = i
		for ; i < k.len; i++ {
			if !k[i].is_digit() {
				c1 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
				break
			}
		}

		if c1 == 0 {
			c1 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
		}
	}

	// sort option
	sort_t := if i < k.len { k[i] } else { space }

	sort_type := match sort_t {
		`b` { SortType.leading }
		`d` { SortType.dictionary }
		`f` { SortType.ignore_case }
		`i` { SortType.ignore_non_printing }
		`n` { SortType.numeric }
		`r` { SortType.reverse }
		else { SortType.ascii }
	}

	if sort_type != .ascii {
		i += 1
	}

	if i < k.len && k[i] == `,` {
		i += 1
		start = i
		for ; i < k.len; i++ {
			if !k[i].is_digit() {
				f2 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
				break
			}
		}

		if f2 == 0 {
			f2 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
		}

		if i < k.len && k[i] == `.` {
			i += 1
			start = i
			for ; i < k.len; i++ {
				if !k[i].is_digit() {
					c2 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
					break
				}
			}

			if c2 == 0 {
				c2 = strconv.atoi(k[start..i]) or { exit_error(err.msg()) }
			}
		}
	}

	return SortKey{
		f1:        f1
		c1:        c1
		f2:        f2
		c2:        c2
		sort_type: sort_type
	}
}
