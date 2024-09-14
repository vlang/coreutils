module main

import os

const test_a = os.temp_dir() + '/test_a.txt'
const test_b = os.temp_dir() + '/test_b.txt'
const test_c = os.temp_dir() + '/test_c.txt'
const test_d = os.temp_dir() + '/test_d.txt'
const test_e = os.temp_dir() + '/test_e.txt'

fn testsuite_begin() {
	create_test_data()
}

fn create_test_data() {
	os.write_lines(test_a, [
		'Now is the time',
		'for all good men',
		'to come to the aid',
		'of their country',
	]) or {}

	os.write_lines(test_b, [
		' Now is the time',
		'   for all good men',
		'      to come to the aid',
		'        of their country',
	]) or {}
	os.write_lines(test_c, [
		'% to come to the aid',
		'* for all good men',
		'# of their country',
		'! Now is the time',
	]) or {}
	os.write_lines(test_d, [
		'\xf1 Now is the time',
		'\xf2 for all good men',
		'\xf3 to come to the aid',
		'\xf4 of their country',
	]) or {}
	os.write_lines(test_e, [
		'100.1 Now is the time',
		'50.2 for all good men',
		'to come to the aid',
		'-24.3 of their country',
	]) or {}
}

fn test_no_options() {
	options := Options{
		files: [test_a]
	}
	assert sort(options) == [
		'Now is the time',
		'for all good men',
		'of their country',
		'to come to the aid',
	]
}

fn test_reverse() {
	options := Options{
		reverse: true
		files:   [test_a]
	}
	assert sort(options) == [
		'to come to the aid',
		'of their country',
		'for all good men',
		'Now is the time',
	]
}

fn test_ignore_case() {
	options := Options{
		ignore_case: true
		files:       [test_a]
	}
	assert sort(options) == [
		'for all good men',
		'Now is the time',
		'of their country',
		'to come to the aid',
	]
}

fn test_ignore_case_reverse() {
	options := Options{
		reverse:     true
		ignore_case: true
		files:       [test_a]
	}
	assert sort(options) == [
		'to come to the aid',
		'of their country',
		'Now is the time',
		'for all good men',
	]
}

fn test_ignore_leading_blanks() {
	options := Options{
		ignore_leading_blanks: true
		files:                 [test_b]
	}
	assert sort(options) == [
		' Now is the time',
		'   for all good men',
		'        of their country',
		'      to come to the aid',
	]
}

fn test_ignore_leading_blanks_reverse() {
	options := Options{
		reverse:               true
		ignore_leading_blanks: true
		files:                 [test_b]
	}
	assert sort(options) == [
		'      to come to the aid',
		'        of their country',
		'   for all good men',
		' Now is the time',
	]
}

fn test_dictionary_order() {
	options := Options{
		dictionary_order: true
		files:            [test_c]
	}
	assert sort(options) == [
		'! Now is the time',
		'* for all good men',
		'# of their country',
		'% to come to the aid',
	]
}

fn test_dictionary_order_everse() {
	options := Options{
		reverse:          true
		dictionary_order: true
		files:            [test_c]
	}
	assert sort(options) == [
		'% to come to the aid',
		'# of their country',
		'* for all good men',
		'! Now is the time',
	]
}

fn test_non_printing() {
	options := Options{
		ignore_non_printing: true
		files:               [test_d]
	}
	assert sort(options) == [
		'\xf1 Now is the time',
		'\xf2 for all good men',
		'\xf4 of their country',
		'\xf3 to come to the aid',
	]
}

fn test_non_printing_reverse() {
	options := Options{
		reverse:             true
		ignore_non_printing: true
		files:               [test_d]
	}
	assert sort(options) == [
		'\xf3 to come to the aid',
		'\xf4 of their country',
		'\xf2 for all good men',
		'\xf1 Now is the time',
	]
}

fn test_numeric() {
	options := Options{
		numeric: true
		files:   [test_e]
	}
	assert sort(options) == [
		'to come to the aid',
		'-24.3 of their country',
		'50.2 for all good men',
		'100.1 Now is the time',
	]
}

fn test_numeric_reverse() {
	options := Options{
		numeric: true
		reverse: true
		files:   [test_e]
	}
	assert sort(options) == [
		'100.1 Now is the time',
		'50.2 for all good men',
		'-24.3 of their country',
		'to come to the aid',
	]
}
