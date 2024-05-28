module main

fn test_string_to_i64_conversions() {
	assert string_to_i64('1')! == 1
	assert string_to_i64('+1')! == 1
	assert string_to_i64('-1')! == -1

	assert string_to_i64('2b')! == 2 * block

	assert string_to_i64('11k')! == 11 * kilo
	assert string_to_i64('12K')! == 12 * kilo
	assert string_to_i64('13KB')! == 13 * kilobyte
	assert string_to_i64('14KiB')! == 14 * kilobyte

	assert string_to_i64('15M')! == 15 * mega
	assert string_to_i64('16MB')! == 16 * megabyte
	assert string_to_i64('17mib')! == 17 * megabyte

	// anything bigger overflows an i64
	overflow := string_to_i64('18T') or { -1 }
	assert overflow == -1

	// invalid checks
	t0 := string_to_i64('') or { -1 }
	assert t0 == -1

	t1 := string_to_i64('1x') or { -1 }
	assert t1 == -1

	t2 := string_to_i64('++1') or { -1 }
	assert t2 == -1
}
