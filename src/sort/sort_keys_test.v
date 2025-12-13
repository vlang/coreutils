module main

import os

const test_aa = os.temp_dir() + '/test_aa.txt'
const test_bb = os.temp_dir() + '/test_bb.txt'

fn testsuite_begin() {
	create_test_data()
}

fn create_test_data() {
	os.write_lines(test_aa, [
		'Now is the time',
		'for all good men',
		'to come to the aid',
		'of their country',
	]) or {}
	os.write_lines(test_bb, [
		' 4.0 Now is the time',
		' 3.0 for all good men',
		' 2.0 to come to the aid',
		' 01. of their country',
	]) or {}
}

// parse field tests

fn test_parse_simple_field() {
	assert parse_sort_key('2') == SortKey{
		f1:        2
		c1:        0
		f2:        0
		c2:        0
		sort_type: .ascii
	}
}

fn test_parse_field_column() {
	assert parse_sort_key('2.1') == SortKey{
		f1:        2
		c1:        1
		f2:        0
		c2:        0
		sort_type: .ascii
	}
}

fn test_parse_field_column_sort_field() {
	assert parse_sort_key('2.1b,3') == SortKey{
		f1:        2
		c1:        1
		f2:        3
		c2:        0
		sort_type: .leading
	}
}

fn test_parse_field_column_sort_field_column() {
	assert parse_sort_key('2.1i,3.3') == SortKey{
		f1:        2
		c1:        1
		f2:        3
		c2:        3
		sort_type: .ignore_non_printing
	}
}

// find field tests
//
fn test_find_field_simple() {
	key := SortKey{
		f1:        2
		c1:        0
		f2:        2
		c2:        0
		sort_type: .ascii
	}
	assert find_field('Now is the time', key, Options{}) == 'is'
}

fn test_find_field_no_f2() {
	key := SortKey{
		f1:        2
		c1:        0
		f2:        0
		c2:        0
		sort_type: .ascii
	}
	assert find_field('Now is the time', key, Options{}) == 'isthetime'
}

fn test_find_field_full_spec() {
	key := SortKey{
		f1:        1
		c1:        2
		f2:        4
		c2:        1
		sort_type: .ascii
	}
	assert find_field('Now is the time', key, Options{}) == 'owisthetim'
}

// sorting

fn test_sort_simple_column() {
	options := Options{
		sort_keys: ['2']
		files:     [test_aa]
	}
	assert sort(options) == [
		'for all good men',
		'to come to the aid',
		'Now is the time',
		'of their country',
	]
}

fn test_sort_full_spec() {
	options := Options{
		sort_keys: ['1.2,4.1']
		files:     [test_aa]
	}
	assert sort(options) == [
		'of their country',
		'to come to the aid',
		'for all good men',
		'Now is the time',
	]
}

fn test_sort_numeric_simple() {
	options := Options{
		sort_keys: ['1n']
		files:     [test_bb]
	}
	assert sort(options) == [
		' 01. of their country',
		' 2.0 to come to the aid',
		' 3.0 for all good men',
		' 4.0 Now is the time',
	]
}
