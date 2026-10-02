// -V sorts the way version numbers read: runs of digits compare as numbers, so
// that 1.10 comes after 1.9, and the other characters weigh in an order that is
// not their byte order. That order is below.

// compare_version compares two keys under -V. Runs of digits weigh as numbers, so
// that 1.10 comes after 1.9, and other characters weigh by version_rank: GNU puts
// the punctuation that introduces a version number first, then digits, then
// letters, then the punctuation that is only part of a name. The table was read off
// GNU 9.4 by sorting every printable character as a one character name.
fn compare_version(a string, b string) int {
	mut i := 0
	mut j := 0
	for {
		// A zero weighs as nothing only when it leads a number. Skipping every zero
		// would make "0x10" weigh as "x10", which sorts after "3KiB" where GNU puts
		// it first, and a blank weighs as itself, which is why "  lead" sorts after
		// "x:y" and before "#h".
		for i < a.len && a[i] == `0` && leads_number(a, i) {
			i++
		}
		for j < b.len && b[j] == `0` && leads_number(b, j) {
			j++
		}
		if i >= a.len || j >= b.len {
			break
		}
		if a[i].is_digit() && b[j].is_digit() {
			// Both are at a digit run: compare the runs as numbers.
			mut ai := i
			for ai < a.len && a[ai].is_digit() {
				ai++
			}
			mut bj := j
			for bj < b.len && b[bj].is_digit() {
				bj++
			}
			r := compare_digit_runs(a[i..ai], b[j..bj])
			if r != 0 {
				return r
			}
			i = ai
			j = bj
			continue
		}
		if a[i] != b[j] {
			return compare_ranks(version_rank(a[i], i), version_rank(b[j], j))
		}
		i++
		j++
	}
	// Whatever is left of one side decides: a prefix comes first.
	if i >= a.len && j >= b.len {
		return 0
	}
	return if i >= a.len { -1 } else { 1 }
}

// leads_number reports whether the zero at pos starts a run of digits, and so
// stands for a number rather than being the character itself.
fn leads_number(s string, pos int) bool {
	return pos + 1 < s.len && s[pos + 1].is_digit()
}

// version_rank is where a character sits in the order -V uses. A dot and a tilde
// come before everything only where they start the key, because there they
// introduce a version number; later in the key they are part of a name and rank
// with the other punctuation. The letters come next, and that last group keeps
// the byte order, so those characters are ranked by adding a constant.
fn version_rank(c u8, pos int) int {
	if pos == 0 {
		if c == `.` {
			return 0
		}
		if c == `~` {
			return 1
		}
	}
	if c == `.` || c == `~` {
		return 1000 + int(c)
	}
	if c.is_digit() {
		return 2 + int(c - `0`)
	}
	if c >= `A` && c <= `Z` {
		return 12 + int(c - `A`)
	}
	if c >= `a` && c <= `z` {
		return 38 + int(c - `a`)
	}
	return 1000 + int(c)
}

fn compare_ranks(a int, b int) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
}

// compare_digit_runs compares two strings of digits as numbers. The leading zeros
// have already been skipped, so the longer run is the larger number unless the
// extra digits are zeros.
fn compare_digit_runs(a string, b string) int {
	mut i := 0
	mut j := 0
	// Find the significant length of each run.
	for i < a.len && a[i] == `0` {
		i++
	}
	for j < b.len && b[j] == `0` {
		j++
	}
	alen := a.len - i
	blen := b.len - j
	if alen != blen {
		return if alen > blen { 1 } else { -1 }
	}
	for k in 0 .. alen {
		if a[i + k] != b[j + k] {
			return if a[i + k] < b[j + k] { -1 } else { 1 }
		}
	}
	return 0
}
