module main

// string_to_i64 returns an option, so it has to be unwrapped explicitly; `!`
// does not work on an option.
fn to_i64(s string) i64 {
	return string_to_i64(s) or { panic('string_to_i64(' + s + ') returned none') }
}

fn test_string_to_i64_conversions() {
	assert to_i64('1') == 1
	assert to_i64('+1') == 1
	assert to_i64('-1') == -1

	assert to_i64('2b') == 2 * block

	assert to_i64('11k') == 11 * kilo
	assert to_i64('12K') == 12 * kilo
	assert to_i64('13KB') == 13 * kilobyte
	assert to_i64('14KiB') == 14 * kilo

	assert to_i64('15M') == 15 * mega
	assert to_i64('16MB') == 16 * megabyte
	assert to_i64('17mib') == 17 * mega

	assert to_i64('18T') == 18 * terra
	assert to_i64('18TB') == 18 * terrabyte
	assert to_i64('18TiB') == 18 * terra

	assert to_i64('10P') == 10 * peta
	assert to_i64('10PB') == 10 * petabyte
	assert to_i64('10PiB') == 10 * peta

	assert to_i64('5E') == 5 * exa
	assert to_i64('5EB') == 5 * exabyte
	assert to_i64('5EiB') == 5 * exa

	// GNU tail's help mentions Z, Y, R and Q, but it rejects all of them
	// with "Value too large for defined data type"
	for big in ['1Z', '1ZB', '1ZiB', '1Y', '1YB', '1R', '1RB', '1Q'] {
		assert string_to_i64(big) == none
	}

	// an out of range multiple must be rejected rather than wrap around
	overflow_e := string_to_i64('20E') or { -1 }
	assert overflow_e == -1

	// invalid checks
	t0 := string_to_i64('') or { -1 }
	assert t0 == -1

	t1 := string_to_i64('1x') or { -1 }
	assert t1 == -1

	t2 := string_to_i64('++1') or { -1 }
	assert t2 == -1
}
