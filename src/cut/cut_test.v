module main

fn test_get_range_start_end() {
	println(@METHOD)
	range := get_range('10-20')!
	assert range == Range{10, 20}
}

fn test_get_range_start_only() {
	println(@METHOD)
	range := get_range('10-')!
	assert range == Range{10, -1}
}

fn test_get_range_end_only() {
	println(@METHOD)
	range := get_range('-5')!
	assert range == Range{0, 5}
}

fn test_get_nth_byte_only() {
	println(@METHOD)
	range := get_range('7')!
	assert range == Range{7, 0}
}

fn test_get_multiple_ranges() {
	println(@METHOD)
	ranges := get_ranges('1-2, 3-4, 10-')!
	assert ranges == [Range{1, 2}, Range{3, 4}, Range{10, -1}]
}

fn test_invalid_range() {
	println(@METHOD)
	get_range('7*9') or {
		assert true
		return
	}
	assert false
}

fn test_validate_args_missing_required() {
	validate_args(Args{}) or {
		assert true
		return
	}
	assert false
}
