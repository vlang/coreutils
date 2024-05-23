module main

fn test_get_range_start_end() {
	println(@METHOD)
	range := get_range('10-20')!
	assert range == [10, 20]!
}

fn test_get_range_start_only() {
	println(@METHOD)
	range := get_range('10-')!
	assert range == [10, -1]!
}

fn test_get_range_end_only() {
	println(@METHOD)
	range := get_range('-5')!
	assert range == [0, 5]!
}

fn test_get_nth_byte_only() {
	println(@METHOD)
	range := get_range('7')!
	assert range == [7, 0]!
}

fn test_invalid_range() {
	println(@METHOD)
	range := get_range('7*9') or {
		assert true
		return
	}
	assert false
}
