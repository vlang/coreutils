module main

import os

const file_a = os.temp_dir() + '/paste_file_a.txt'
const file_b = os.temp_dir() + '/paste_file_b.txt'
const file_c = os.temp_dir() + '/paste_file_c.txt'
const file_d = os.temp_dir() + '/paste_file_d.txt'

fn testsuite_begin() {
	os.write_lines(file_a, [
		'1',
		'2',
		'3',
		'4',
	]) or {}
	os.write_lines(file_b, [
		'a',
		'b',
		'c',
		'd',
	]) or {}
	os.write_lines(file_c, [
		'Now is',
		'the time',
		'for all',
		'good men',
	]) or {}
	os.write_lines(file_d, [
		'to come',
		'to the',
		'aid of',
		'their country',
	]) or {}
}

fn add(s string, cb fn (string)) {
	cb(s)
}

fn test_serialize_option() {
	options := Options{
		serial: true
		files:  [file_a, file_b]
	}
	mut lines := []string{}
	mut rlines := &lines
	paste(options, fn [mut rlines] (s string) {
		rlines << s
	})
	assert lines == ['1\t2\t3\t4', 'a\tb\tc\td']
}

fn test_serialize_option2() {
	options := Options{
		serial: true
		files:  [file_c, file_d]
	}
	mut lines := []string{}
	mut rlines := &lines
	paste(options, fn [mut rlines] (s string) {
		rlines << s
	})
	assert lines == ['Now is\tthe time\tfor all\tgood men', 'to come\tto the\taid of\ttheir country']
}

fn test_single_delimiter() {
	options := Options{
		files: [file_c, file_d]
	}
	mut lines := []string{}
	mut rlines := &lines
	paste(options, fn [mut rlines] (s string) {
		rlines << s
	})
	assert lines == [
		// vfmt off
		'Now is\tto come',
		'the time\tto the',
		'for all\taid of',
		'good men\ttheir country'
		// vfmt on
	]
}

fn test_multiple_delimiters() {
	options := Options{
		next_delimiter: next_delimiter('%|')
		files:          [file_c, file_d, file_c]
	}
	mut lines := []string{}
	mut rlines := &lines
	paste(options, fn [mut rlines] (s string) {
		rlines << s
	})
	assert lines == [
		// vfmt off
		'Now is%to come|Now is',
		'the time%to the|the time',
		'for all%aid of|for all',
		'good men%their country|good men'
		// vfmt on
	]
}
