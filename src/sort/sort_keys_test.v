module main

import common.testing

// These are unit tests of the key parser, so they need no built program.
const rig = testing.prepare_rig(util: 'sort')

// A key definition is F[.C][OPTS][,F[.C][OPTS]]. These tests read the positions
// and the ordering out of one, and then the text a key covers.

fn base_ordering() Ordering {
	return Ordering{}
}

fn test_key_start_field_only() {
	key := parse_key('2', base_ordering())

	assert key.from_field == 2
	assert key.from_char == 0
	assert !key.has_to
}

fn test_key_start_field_and_char() {
	key := parse_key('2.1', base_ordering())

	assert key.from_field == 2
	assert key.from_char == 1
	assert !key.has_to
}

fn test_key_with_an_end() {
	key := parse_key('2,3', base_ordering())

	assert key.from_field == 2
	assert key.to_field == 3
	assert key.has_to
}

fn test_key_with_end_chars() {
	key := parse_key('2.1,3.3', base_ordering())

	assert key.from_field == 2
	assert key.from_char == 1
	assert key.to_field == 3
	assert key.to_char == 3
}

// The ordering letters may sit on either side of the comma, and mean the same.

fn test_ordering_letter_before_the_comma() {
	key := parse_key('2n,2', base_ordering())

	assert key.from_field == 2
	assert key.has_to
	assert key.ordering.mode == OrderMode.numeric
}

fn test_ordering_letter_after_the_end() {
	key := parse_key('2,2n', base_ordering())

	assert key.from_field == 2
	assert key.has_to
	assert key.ordering.mode == OrderMode.numeric
}

fn test_key_inherits_the_global_ordering() {
	mut global := Ordering{}
	global.fold_case = true
	key := parse_key('2', global)

	assert key.ordering.fold_case
}

fn test_key_ordering_overrides_the_global_one() {
	mut global := Ordering{}
	global.mode = .numeric
	key := parse_key('2f', global)

	// A key names only the options it mentions, so -f adds the folding and leaves
	// the -n that was given on the command line in place.
	assert key.ordering.mode == .numeric
	assert key.ordering.fold_case
}

// Without -t, a field starts at the blank before it, and the first field has no
// blank before it to start from.

fn test_key_of_the_second_field_includes_the_blank_before_it() {
	key := parse_key('2,2', base_ordering())
	// GNU counts a field from the whitespace before it, so the blank is part of
	// the key.
	assert extract_key('Now is the time', &key, ' ', false, false) == ' is'
}

fn test_key_of_the_first_field_is_the_whole_field() {
	key := parse_key('1,1', base_ordering())
	assert extract_key('Now is the time', &key, ' ', false, false) == 'Now'
}

fn test_ignore_blanks_drops_the_blank_before_the_field() {
	key := parse_key('2,2', base_ordering())
	assert extract_key('Now is the time', &key, ' ', false, true) == 'is'
}

fn test_field_separator_splits_the_fields() {
	key := parse_key('2,2', base_ordering())
	assert extract_key('Now:is:the', &key, ':', true, false) == 'is'
}

// A key with no end runs to the end of the line.

fn test_key_without_an_end_runs_to_the_end() {
	key := parse_key('2', base_ordering())
	assert extract_key('Now is the time', &key, ' ', false, false) == ' is the time'
}

fn test_key_past_the_end_of_the_line_is_empty() {
	key := parse_key('3,3', base_ordering())
	assert extract_key('Now is', &key, ' ', false, false) == ''
}

// A character position is the last character of the key, counted from the start
// of the field.

fn test_key_end_char_cuts_the_field_short() {
	key := parse_key('1.2,1.4', base_ordering())
	assert extract_key('abcdef', &key, ' ', false, false) == 'bcd'
}

fn test_key_start_char_moves_the_start() {
	key := parse_key('1.2', base_ordering())
	assert extract_key('abcdef', &key, ' ', false, false) == 'bcdef'
}
