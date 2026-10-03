module main

// The expected values here were read off GNU ls 9.4, not derived from the
// implementation. Two rules are being pinned down:
//
//   -h divides by 1024 and uses an uppercase suffix, --si divides by 1000 and
//   uses a lowercase one. The `si` argument is therefore true for --si.
//
//   The rounding is a ceiling, not to nearest. GNU prints 2500 bytes as 2.5K
//   where rounding to nearest would give 2.4K, and 10240 as 10K while 10241 is
//   11K. One decimal is kept below ten and dropped at or above it, so 4096 is
//   4.0K and 102400 is 100K.
fn test_readable_size() {
	// Below the base a size is printed as it stands, with no suffix.
	assert readable_size(0, true) == '0'
	assert readable_size(2, true) == '2'
	assert readable_size(1023, false) == '1023'
	assert readable_size(100, false) == '100'

	// 1024 is the first value that -h scales, and 1000 the first for --si, so
	// 1023 is still unscaled by -h and already 1.1k under --si.
	assert readable_size(1024, false) == '1.0K'
	assert readable_size(1024, true) == '1.1k'
	assert readable_size(1023, true) == '1.1k'

	// The ceiling, at each of the two points where a nearest rounding would
	// disagree.
	assert readable_size(2500, false) == '2.5K'
	assert readable_size(2900, false) == '2.9K'
	assert readable_size(2999, false) == '3.0K'
	assert readable_size(1025, false) == '1.1K'

	// Exact multiples keep their exact value rather than gaining a tenth.
	assert readable_size(2048, false) == '2.0K'
	assert readable_size(4096, false) == '4.0K'
	assert readable_size(5120, false) == '5.0K'

	// At ten the decimal goes away.
	assert readable_size(10239, false) == '10K'
	assert readable_size(10240, false) == '10K'
	assert readable_size(10241, false) == '11K'

	assert readable_size(4095, false) == '4.0K'
	assert readable_size(4097, false) == '4.1K'
	assert readable_size(10_000, false) == '9.8K'
	assert readable_size(20_000, false) == '20K'
	assert readable_size(200_000, false) == '196K'
	assert readable_size(102_400, false) == '100K'

	// --si, on a 1000 base with a lowercase suffix.
	assert readable_size(4095, true) == '4.1k'
	assert readable_size(100_000, true) == '100k'
	assert readable_size(200_000, true) == '200k'

	// Larger units still round up, and the mantissa stays below ten.
	// 100000000 / 1024 / 1024 is 95.37, which the ceiling rule takes to 96.
	assert readable_size(100_000_000, false) == '96M'
	assert readable_size(100_000_000, true) == '100m'
	assert readable_size(8_000_000_000_000_000_000, true) == '8.0e'
}
