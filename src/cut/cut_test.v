module main

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

const text_a = 'Now is the time for all good men to come the aid of their country.'
const text_u = 'Now 任意的 随机的 胡乱的'

fn test_single_range_bytes() {
	args := Args{
		byte_range_list: [Range{5, 5}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['i']
}

fn test_single_range_chars() {
	args := Args{
		char_range_list: [Range{5, 5}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == ['任']
}

fn test_simple_range_cut_bytes() {
	args := Args{
		byte_range_list: [Range{8, 15}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['the time']
}

fn test_simple_range_cut_chars() {
	args := Args{
		char_range_list: [Range{8, 15}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == [' 随机的 胡乱的']
}

fn test_index_to_end_bytes() {
	args := Args{
		byte_range_list: [Range{8, -1}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['the time for all good men to come the aid of their country.']
}

fn test_index_to_end_chars() {
	args := Args{
		char_range_list: [Range{8, -1}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == [' 随机的 胡乱的']
}

fn test_multiple_index_to_index_bytes() {
	args := Args{
		byte_range_list: [Range{1, 3}, Range{5, 7}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['Nowis ']
}

fn test_multiple_index_to_index_chars() {
	args := Args{
		char_range_list: [Range{1, 3}, Range{5, 7}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == ['Now任意的']
}

fn test_mutiple_overlapping_ranges_bytes() {
	args := Args{
		byte_range_list: [Range{4, 3}, Range{2, 6}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['ow is']
}

fn test_mutiple_overlapping_ranges_chars() {
	args := Args{
		char_range_list: [Range{4, 3}, Range{2, 6}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == ['ow 任意']
}

fn test_mutiple_overlapping_ranges_unordered_bytes() {
	args := Args{
		byte_range_list: [Range{1, 3}, Range{5, 6}, Range{1, 15}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_bytes(text_a, args, out_fn)
	assert result == ['Now is the time']
}

fn test_mutiple_overlapping_ranges_unordered_chars() {
	args := Args{
		char_range_list: [Range{1, 3}, Range{5, 6}, Range{1, 15}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_chars(text_u, args, out_fn)
	assert result == ['Now 任意的 随机的 胡乱的']
}

const text_f = [
	'Name\tAge\tDepartment',
	'John Smith\t36\tHR',
	'John Wayne\t48\tFinance',
	'Edward King\t40\tFinance',
	'Stephen Fry\t50\tIT',
]

fn test_single_range_fields() {
	args := Args{
		field_range_list: [Range{2, 2}]
	}
	expected := [
		'Age',
		'36',
		'48',
		'40',
		'50',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(text_f, args, out_fn)
	assert result == expected
}

fn test_range_fields() {
	args := Args{
		// set range end past last field to
		// test range clamping
		field_range_list: [Range{2, 5}]
	}
	expected := [
		'Age\tDepartment',
		'36\tHR',
		'48\tFinance',
		'40\tFinance',
		'50\tIT',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(text_f, args, out_fn)
	assert result == expected
}

fn test_disjoint_ranges_fields() {
	args := Args{
		field_range_list: [Range{1, 1}, Range{3, 3}]
	}
	expected := [
		'Name\tDepartment',
		'John Smith\tHR',
		'John Wayne\tFinance',
		'Edward King\tFinance',
		'Stephen Fry\tIT',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(text_f, args, out_fn)
	assert result == expected
}

fn test_no_delimiter_line_printed() {
	args := Args{
		field_range_list: [Range{1, 1}, Range{3, 3}]
	}
	input := [
		'Name Age Department',
		'Name\tAge\tDepartment',
	]
	expected := [
		'Name Age Department',
		'Name\tDepartment',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(input, args, out_fn)
	assert result == expected
}

fn test_no_delimiter_line_not_printed() {
	args := Args{
		only_delimited:   true
		field_range_list: [Range{1, 1}, Range{3, 3}]
	}
	input := [
		'Name Age Department',
		'Name\tAge\tDepartment',
	]
	expected := [
		'Name\tDepartment',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(input, args, out_fn)
	assert result == expected
}

const text_f_empty_no_tab = [
	'Name	Age	Department',
	'this has no tabs',
	'John Smith	36	HR',
	'',
	'Stephen Fry	50	IT',
]

fn test_empty_and_no_delimiters_fields() {
	args := Args{
		field_range_list: [Range{1, 1}, Range{2, 2}]
	}
	// keep no tab line, and empty line
	expected := [
		'Name	Age',
		'this has no tabs',
		'John Smith	36',
		'',
		'Stephen Fry	50',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(text_f_empty_no_tab, args, out_fn)
	assert result == expected
}

fn test_empty_and_no_delimiters_only_delimited_fields() {
	args := Args{
		only_delimited:   true
		field_range_list: [Range{1, 1}, Range{2, 2}]
	}
	// drop no tab line, and empty line
	expected := [
		'Name	Age',
		'John Smith	36',
		'',
		'Stephen Fry	50',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(text_f_empty_no_tab, args, out_fn)
	assert result == expected
}

const csv = [
	'Name, Age, Department',
	'John Smith, 23, R&D',
]

fn test_custom_input_delimiter() {
	args := Args{
		delimiter:        `,`
		output_delimiter: ','
		field_range_list: [Range{1, 1}, Range{2, 2}]
	}
	expected := [
		'Name, Age',
		'John Smith, 23',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(csv, args, out_fn)
	assert result == expected
}

fn test_custom_output_delimiter() {
	args := Args{
		delimiter:        `,`
		output_delimiter: '::'
		field_range_list: [Range{1, 1}, Range{2, 2}]
	}
	expected := [
		'Name:: Age',
		'John Smith:: 23',
	]
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines(csv, args, out_fn)
	assert result == expected
}

fn test_complement_of_range_bytes() {
	args := Args{
		complement:      true
		byte_range_list: [Range{4, 10}]
	}
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	cut_lines([text_a], args, out_fn)
	assert result == ['Now time for all good men to come the aid of their country.']
}

fn test_zero_terminiated_lines() {
	bytes := 'Now is the time\0for all good men\0to come to the aid\0of their country'.bytes()
	lines := read_lines_zero_terminated(bytes)
	expected := [
		'Now is the time',
		'for all good men',
		'to come to the aid',
		'of their country',
	]
	assert lines == expected
}
