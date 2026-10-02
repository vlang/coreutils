// The ordering options, which decide how one key is compared with another. Any of
// them may be given on the command line, and a key definition may override the
// ones set globally.
enum OrderMode {
	ascii
	numeric
	general
	human
	month
	version
}

struct Ordering {
mut:
	mode            OrderMode
	ignore_blanks   bool
	dictionary      bool
	fold_case       bool
	ignore_nonprint bool
	reverse         bool
	// stable turns off the last-resort comparison, so that lines which compare
	// equal keep the order they came in with.
	stable bool
	// random is -R, which shuffles but keeps lines with equal keys together.
	random bool
}

// compare_key compares a and b under one ordering, including the comparison of
// the part that follows a number, so that a non-zero result means the two keys
// are ordered and a zero result means the next key, or the last-resort
// comparison, has to decide.
fn compare_key(ordering &Ordering, a &string, b &string) int {
	x := order_key(ordering, a)
	y := order_key(ordering, b)

	match ordering.mode {
		.general, .numeric, .human {
			// Only the number weighs here. GNU does not look at the text that
			// follows it, which is why "1a" and "01b" sort as their whole lines
			// do rather than by the a and b.
			rn := compare_values(x.value, y.value)
			if rn != 0 {
				return flip(ordering.reverse, rn)
			}
		}
		.ascii {
			rt := compare_bytes(x.text, y.text)
			if rt != 0 {
				return flip(ordering.reverse, rt)
			}
		}
		.month {
			rm := compare_values(f64(x.month), f64(y.month))
			if rm != 0 {
				return flip(ordering.reverse, rm)
			}
			// A month weighs with the text after it, so "JAN" comes before "JANUARY".
			rs2 := compare_bytes(x.rest, y.rest)
			if rs2 != 0 {
				return flip(ordering.reverse, rs2)
			}
		}
		.version {
			rv := compare_version(x.text, y.text)
			if rv != 0 {
				return flip(ordering.reverse, rv)
			}
			// A version sort compares the whole key, digits and all, so there is
			// nothing left over for the last resort but the lines themselves.
			return 0
		}
		else {
			rt := compare_bytes(x.text, y.text)
			if rt != 0 {
				return flip(ordering.reverse, rt)
			}
		}
	}
	return 0
}

// order_key is one key as the ordering wants to see it: the characters this
// ordering weighs, and the value of the number or month that may start it.
struct OrderedKey {
	text  string
	value f64
	month int
	rest  string
}

// order_key applies the ordering options to s. The transformations are the ones
// GNU applies, in this order: leading blanks, then the characters -d and -i skip,
// then the case folding. A numeric ordering reads what is left.
fn order_key(ordering &Ordering, s string) OrderedKey {
	mut text := s
	if ordering.ignore_blanks {
		text = text.trim_left(' \t\n\v\f\r')
	}
	if ordering.dictionary {
		mut out := []u8{}
		for c in text {
			if c.is_digit() || (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || is_blank(c) {
				out << c
			}
		}
		text = out.bytestr()
	}
	if ordering.ignore_nonprint {
		mut out := []u8{}
		for c in text {
			if c >= ` ` && c <= `~` {
				out << c
			}
		}
		text = out.bytestr()
	}
	if ordering.fold_case {
		text = fold_case(text)
	}

	match ordering.mode {
		.numeric {
			n := number_prefix(text, .string)
			return OrderedKey{ text: text, value: n.value, rest: n.rest }
		}
		.general {
			n := number_prefix(text, .general)
			return OrderedKey{ text: text, value: n.value, rest: n.rest }
		}
		.human {
			n := number_prefix(text, .human)
			return OrderedKey{ text: text, value: n.value, rest: n.rest }
		}
		.month {
			month, rest := month_prefix(text)
			return OrderedKey{ text: text, month: month, rest: rest }
		}
		else {
			return OrderedKey{ text: text }
		}
	}
}

// compare_values orders two f64, putting a NaN before everything and an infinity
// at either end, which is the order GNU documents for -g.
fn compare_values(a f64, b f64) int {
	// A NaN is the only value that is not equal to itself.
	a_nan := a != a
	b_nan := b != b
	if a_nan {
		return if b_nan { 0 } else { -1 }
	}
	if b_nan {
		return 1
	}
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

// compare_bytes is a plain byte comparison, the order LC_ALL=C gives.
fn compare_bytes(a string, b string) int {
	mut i := 0
	for i < a.len && i < b.len {
		if a[i] != b[i] {
			return if a[i] < b[i] { -1 } else { 1 }
		}
		i++
	}
	if i >= a.len && i >= b.len {
		return 0
	}
	return if i >= a.len { -1 } else { 1 }
}

fn flip(reverse bool, result int) int {
	return if reverse { -result } else { result }
}

// fold_case maps the ASCII letters to one case, so that a comparison under -f
// weighs them the same whichever case they came in.
fn fold_case(s string) string {
	mut out := []u8{len: s.len, cap: s.len}
	for i, c in s {
		if c >= `A` && c <= `Z` {
			out[i] = c + 32
		} else if c >= 0xc0 && c <= 0xde && c != 0xd7 {
			out[i] = c + 32
		} else {
			out[i] = c
		}
	}
	return out.bytestr()
}

const month_names = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov',
	'dec']

// month_prefix reads a month name at the start of s, ignoring case, and returns
// its number and the rest. A line that does not start with a month gets -1, so
// that it comes before every month, as at GNU.
fn month_prefix(s string) (int, string) {
	if s.len < 3 {
		return -1, s
	}
	mut name := []u8{cap: 3}
	for i in 0 .. 3 {
		c := s[i] | 0x20
		if c < `a` || c > `z` {
			return -1, s
		}
		name << c
	}
	folded := name.bytestr()
	for m, candidate in month_names {
		if folded == candidate {
			return m, s[3..]
		}
	}
	return -1, s
}
