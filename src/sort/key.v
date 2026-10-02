// A key definition, as -k takes it: F[.C][OPTS][,F[.C][OPTS]], where F is a field
// number and C a character position in that field, both counting from one.
struct SortKey {
mut:
	from_field   int
	from_char    int
	to_field     int
	to_char      int
	has_to       bool
	ordering     Ordering
	has_ordering bool
}

// parse_keys turns the -k arguments into key definitions. The orderings a key
// names override the global ones; it inherits each global option that it does not
// mention.
fn parse_keys(specs []string, base Ordering) []SortKey {
	mut keys := []SortKey{}
	for spec in specs {
		keys << parse_key(spec, base)
	}
	return keys
}

fn parse_key(spec string, base Ordering) SortKey {
	mut key := SortKey{
		from_field: 0
		from_char:  0
		to_field:   0
		to_char:    0
		ordering:   base
	}

	// The definition is read as: a number, an optional .number, any ordering
	// letters, then an optional ,number with an optional .number. The ordering
	// letters may sit anywhere among the numbers, which is what makes -k2n,2 and
	// -k2,2n mean the same thing.
	mut from_field := 0
	mut from_char := 0
	mut to_field := 0
	mut to_char := 0
	mut has_to := false
	mut ordering := base
	mut saw_field := false
	mut i := 0
	// which number comes next: 0 for the start, 1 for the end
	mut next := 0

	for i < spec.len {
		c := spec[i]
		if c.is_digit() {
			// A field number is the digits, and nothing may come between them and
			// the dot or comma that may follow. An ordering letter may sit in
			// between, though: -k2n,2 and -k2,2n mean the same thing.
			n, j := read_field_number(spec, i)
			if next == 0 {
				from_field = n
				from_char = 0
				saw_field = true
			} else {
				to_field = n
				to_char = 0
				has_to = true
			}
			i = j
			continue
		}
		if c == `.` {
			// A position after the dot, so a digit run must follow.
			n, j := read_field_number(spec, i + 1)
			if j == i + 1 {
				key_error(spec)
			}
			if next == 0 {
				from_char = n
			} else {
				to_char = n
			}
			i = j
			continue
		}
		if c == `,` {
			if !saw_field {
				key_error(spec)
			}
			next = 1
			i++
			continue
		}
		// An ordering letter may only follow the field number, which is why -k2n
		// reads but -kn does not.
		if !saw_field {
			error_only("invalid number at field start: invalid count at start of '${spec}'")
		}
		ordering = apply_ordering_letter(mut ordering, c, spec)
		i++
	}
	// A definition that does not start with a field number is not a key at all,
	// which is the mistake GNU calls an invalid count at the start of it.
	// A definition that does not start with a field number is not a key at all.
	if !saw_field {
		error_only("invalid number at field start: invalid count at start of '${spec}'")
	}
	// A field number of zero is not a position. GNU rejects the whole definition
	// rather than reading it as the end of the line.
	if from_field == 0 || (has_to && to_field == 0) {
		error_only("field number is zero: invalid field specification '${spec}'")
	}

	key.from_field = from_field
	key.from_char = from_char
	key.to_field = to_field
	key.to_char = to_char
	key.has_to = has_to
	key.ordering = ordering
	return key
}

// read_field_number reads the digits at i, and returns the number and where it
// stopped. V does not allow a mutable scalar parameter, hence the pair.
fn read_field_number(spec string, i int) (int, int) {
	mut j := i
	for j < spec.len && spec[j].is_digit() {
		j++
	}
	mut n := 0
	for c in spec[i..j] {
		n = n * 10 + int(c - `0`)
	}
	return n, j
}

// ordering_letters are the ones a key definition may name after its positions.
const ordering_letters = 'bdfghiMhnRrV'

// apply_ordering_letter applies one ordering letter to a key's ordering. The
// Ordering fields are declared mut, so a local copy is enough.
fn apply_ordering_letter(mut ordering Ordering, c u8, spec string) Ordering {
	match c {
		`b` { ordering.ignore_blanks = true }
		`d` { ordering.dictionary = true }
		`f` { ordering.fold_case = true }
		`i` { ordering.ignore_nonprint = true }
		`n` { ordering.mode = .numeric }
		`g` { ordering.mode = .general }
		`h` { ordering.mode = .human }
		`M` { ordering.mode = .month }
		`V` { ordering.mode = .version }
		`r` { ordering.reverse = true }
		`R` { ordering.random = true }
		else { key_error(spec) }
	}
	return ordering
}

// key_error reports a malformed key definition. GNU does not follow this with the
// advice about --help.
@[noreturn]
fn key_error(spec string) {
	error_only('invalid key ${spec}')
}

// extract_key returns the part of line that a key definition covers.
fn extract_key(line string, key &SortKey, separator string, has_separator bool,
	ignore_blanks bool) string {
	mut start := field_start(line, key.from_field, separator, has_separator, ignore_blanks)
	// A position of zero means the start of the field, so that is what a missing
	// .C has to mean.
	if key.from_char > 1 {
		start += key.from_char - 1
	}
	if start > line.len {
		start = line.len
	}

	// Without an end position the key runs to the end of the line, which is what
	// -k2 on its own does.
	mut end := line.len
	if key.has_to && key.to_field > 0 {
		if key.to_char > 0 {
			// A character position is a place in the field, counted from its
			// start, and it is the last character of the key rather than a count
			// from it. A line shorter than that simply stops early.
			end = field_start(line, key.to_field, separator, has_separator,
				ignore_blanks) + key.to_char
		} else {
			end = field_end(line, key.to_field, separator, has_separator, ignore_blanks)
		}
	}
	if end > line.len {
		end = line.len
	}
	if end < start {
		end = start
	}
	return line[start..end]
}

// field_start returns where a field begins. With -t it is the start of the field
// itself; without -t a field runs from the blank that introduced it, unless -b says
// to ignore those blanks.
fn field_start(line string, field int, separator string, has_separator bool,
	ignore_blanks bool) int {
	mut pos := 0
	mut f := 1
	mut n := line.len
	// Whether a field with characters in it has been stepped over. Without it, a
	// line of nothing but blanks would have an empty first field and a second field
	// covering the whole line, where GNU gives an empty second field.
	mut consumed := false

	for f < field {
		if pos >= n {
			return n
		}
		if has_separator {
			next := find_from(line, pos, separator)
			if next < 0 {
				return n
			}
			pos = next + separator.len
			consumed = true
		} else {
			// A field is a run of non-blanks, so the blanks before it belong to
			// it only when -b is not in effect. Stepping over them first is what
			// makes a line that begins with blanks have no leading field.
			for pos < n && is_blank(line[pos]) {
				pos++
			}
			if pos < n {
				consumed = true
			}
			for pos < n && !is_blank(line[pos]) {
				pos++
			}
		}
		f++
	}
	if pos > n {
		return n
	}

	if has_separator {
		return pos
	}
	if ignore_blanks {
		// The loop above stops on the blank that introduces this field, so -b has
		// to step past it.
		for pos < n && is_blank(line[pos]) {
			pos++
		}
		return pos
	}
	if field == 1 || !consumed {
		// The first field has no whitespace before it to count from, and neither
		// has a field that does not exist.
		return pos
	}
	// Any other field starts at the blank that introduced it.
	mut back := pos
	for back > 0 && is_blank(line[back - 1]) {
		back--
	}
	return back
}

// field_end returns where a field ends, which is after its last character.
fn field_end(line string, field int, separator string, has_separator bool,
	ignore_blanks bool) int {
	mut n := line.len
	start := field_start(line, field, separator, has_separator, ignore_blanks)
	if start >= n {
		return n
	}

	if has_separator {
		next := find_from(line, start, separator)
		return if next < 0 { n } else { next }
	}

	// Without -t a field runs from the blank before it to the blank after it, so
	// the blanks at its start have to be stepped over before its end can be found.
	mut pos := start
	for pos < n && is_blank(line[pos]) {
		pos++
	}
	for pos < n && !is_blank(line[pos]) {
		pos++
	}
	return pos
}

// find_next_non_blank returns the position of the next character that is not a
// blank, or -1 when there is none.
fn find_next_non_blank(line string, from int) int {
	mut pos := from
	for pos < line.len {
		if !is_blank(line[pos]) {
			return pos
		}
		pos++
	}
	return -1
}

// find_from returns where sep first appears at or after pos, or -1 when it does
// not. V's string module has no search that starts at a position.
fn find_from(line string, pos int, sep string) int {
	mut i := pos
	for i + sep.len <= line.len {
		if line[i..i + sep.len] == sep {
			return i
		}
		i++
	}
	return -1
}
