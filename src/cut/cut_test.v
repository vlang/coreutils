module main

const text_a = 'Now is the time for all good men to come the aid of their country.'

fn test_get_range_start_end() {
	range := get_range('10-20')!
	assert range == Range{10, 20}
}

fn test_get_range_start_only() {
	range := get_range('10-')!
	assert range == Range{10, -1}
}

fn test_get_range_end_only() {
	range := get_range('-5')!
	assert range == Range{1, 5}
}

fn test_get_nth_byte_only() {
	range := get_range('7')!
	assert range == Range{7, 7}
}

fn test_get_multiple_ranges() {
	ranges := get_ranges('1-2, 3-4, 10-')!
	assert ranges == [Range{1, 2}, Range{3, 4}, Range{10, -1}]
}

fn test_invalid_range() {
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

fn test_simple_range_cut_bytes() {
	args := Args{
		byte_range_list: [Range{8, 15}]
	}
	assert cut(text_a, args) == 'the time'
}

fn test_index_to_end_bytes() {
	args := Args{
		byte_range_list: [Range{8, -1}]
	}
	assert cut(text_a, args) == 'the time for all good men to come the aid of their country.'
}

fn test_multiple_index_to_index() {
	args := Args{
		byte_range_list: [Range{1, 3}, Range{5, 7}]
	}
	assert cut(text_a, args) == 'Nowis '
}

fn test_mutiple_overlapping_ranges() {
	args := Args{
		byte_range_list: [Range{4, 3}, Range{2, 6}]
	}
	assert cut(text_a, args) == 'ow is'
}

fn test_mutiple_overlapping_ranges_unordered() {
	args := Args{
		byte_range_list: [Range{1, 3}, Range{5, 6}, Range{1, 15}]
	}
	assert cut(text_a, args) == 'Now is the time'
}
