module main

import os
import time

fn print_lines(lines []string) {
	println(' ')
	println('-------------')
	for line in lines {
		println(line)
	}
}

fn temp_file_name() string {
	dir := os.temp_dir()
	file := '${dir}/t${time.ticks()}'
	return file
}

fn to_tmp_file(data []string) string {
	file := temp_file_name()
	os.write_file(file, data.join_lines()) or { panic('error') }
	return file
}

fn setup() (fn (s string), fn () []string) {
	mut result := []string{}
	mut result_ref := &result
	out_fn := fn [mut result_ref] (s string) {
		result_ref << s
	}
	result_fn := fn [mut result_ref] () []string {
		return *result_ref
	}
	return out_fn, result_fn
}

fn test_basic_wrap() {
	println(@METHOD)
	input := [
		'Now is the time for all good men to come to the aid of their country.',
		'',
		'Now is the time for all good men to come to the aid of their country.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-w', '30', tmp], out_fn)
	os.rm(tmp)!
	// print_lines(output)
	expected := [
		'Now is the time for all good',
		'men to come to the aid of',
		'their country.',
		'',
		'Now is the time for all good',
		'men to come to the aid of',
		'their country.',
	]
	assert result_fn() == expected
}

fn test_narrow_to_formatted() {
	println(@METHOD)
	input := [
		'Hello World',
		'',
		'Hi there!',
		'How are you?',
		'',
		'Just do-it.',
		'Believe it.',
		'',
		'banana,',
		'papaya,',
		'mango',
		'',
		'Much ado about nothing.',
		'He he he.',
		'Adios amigo.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', tmp], out_fn)
	os.rm(tmp)!
	// print_lines(output)
	expected := [
		'Hello World',
		'',
		'Hi there!  How are you?',
		'',
		'Just do-it.  Believe it.',
		'',
		'banana, papaya, mango',
		'',
		'Much ado about nothing.  He he he.  Adios amigo.',
	]
	assert result_fn() == expected
}

fn test_line_indents_denote_new_paragraph() {
	println(@METHOD)
	input := [
		'This is a single line paragraph',
		'    because this line has a different indent',
		'',
		'Otherwise these other lines comprise a simple',
		'multline paragraph.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-w', '35', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'This is a single line paragraph',
		'    because this line has a',
		'    different indent',
		'',
		'Otherwise these other lines',
		'comprise a simple multline',
		'paragraph.',
	]
	assert result_fn() == expected
}

fn test_numbered_list_no_options() {
	println(@METHOD)
	input := [
		'A list of items',
		'',
		'    1. Now is the time for all good men to come to the aid of their country.',
		'    2. Now is the time for all good men to come to the aid of their country.',
		'    3. Now is the time for all good men to come to the aid of their country.',
		'    4. Now is the time for all good men to come to the aid of their country.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', tmp], out_fn)
	os.rm(tmp)!
	// print_lines(output)
	expected := [
		'A list of items',
		'',
		'    1. Now is the time for all good men to come to the aid of their',
		'    country.  2. Now is the time for all good men to come to the aid of',
		'    their country.  3. Now is the time for all good men to come to the aid',
		'    of their country.  4. Now is the time for all good men to come to the',
		'    aid of their country.',
	]
	assert result_fn() == expected
}

fn test_numbered_list_w_40() {
	println(@METHOD)
	input := [
		'A list of items',
		'',
		'    1. Now is the time for all good men to come to the aid of their country.',
		'    2. Now is the time for all good men to come to the aid of their country.',
		'    3. Now is the time for all good men to come to the aid of their country.',
		'    4. Now is the time for all good men to come to the aid of their country.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-w', '40', tmp], out_fn)
	os.rm(tmp)!
	// print_lines(output)
	expected := [
		'A list of items',
		'',
		'    1. Now is the time for all good men',
		'    to come to the aid of their country.',
		'    2. Now is the time for all good men',
		'    to come to the aid of their country.',
		'    3. Now is the time for all good men',
		'    to come to the aid of their country.',
		'    4. Now is the time for all good men',
		'    to come to the aid of their country.',
	]
	assert result_fn() == expected
}

fn test_split_only() {
	println(@METHOD)
	input := [
		'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur dignissim',
		'venenatis pede. Quisque dui dui, ultricies ut, facilisis non, pulvinar non. Duis quis arcu a purus volutpat iaculis. Morbi id dui in diam ornare',
		'dictum. Praesent consectetuer vehicula ipsum. Praesent tortor massa, congue et,',
		'ornare in, posuere eget, pede.',
		'',
		'Vivamus rhoncus. Quisque lacus. In hac habitasse platea dictumst. Nullam mauris',
		'tellus, sollicitudin non, semper eget, sodales non, pede. Phasellus varius',
		'ullamcorper libero. Fusce ipsum lorem, iaculis nec, vulputate vitae, suscipit',
		'vel, tortor. Cras varius.',
		'',
		'Nullam fringilla pellentesque orci. Nulla eu ante pulvinar velit rhoncus',
		'lacinia. Morbi fringilla lacus quis arcu. Vestibulum sem quam, dapibus in,',
		'fringilla ut, venenatis ut, neque.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-s', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur',
		'dignissim',
		'venenatis pede. Quisque dui dui, ultricies ut, facilisis non, pulvinar non.',
		'Duis quis arcu a purus volutpat iaculis. Morbi id dui in diam ornare',
		'dictum. Praesent consectetuer vehicula ipsum. Praesent tortor massa, congue',
		'et,',
		'ornare in, posuere eget, pede.',
		'',
		'Vivamus rhoncus. Quisque lacus. In hac habitasse platea dictumst. Nullam',
		'mauris',
		'tellus, sollicitudin non, semper eget, sodales non, pede. Phasellus varius',
		'ullamcorper libero. Fusce ipsum lorem, iaculis nec, vulputate vitae,',
		'suscipit',
		'vel, tortor. Cras varius.',
		'',
		'Nullam fringilla pellentesque orci. Nulla eu ante pulvinar velit rhoncus',
		'lacinia. Morbi fringilla lacus quis arcu. Vestibulum sem quam, dapibus in,',
		'fringilla ut, venenatis ut, neque.',
	]
	assert result_fn() == expected
}

fn test_indents_no_blank_lines() {
	println(@METHOD)
	input := [
		'Love is patient, love is kind. It does not envy,',
		' it does not boast, it is not proud. It is not rude,',
		' it is not self-seeking, it is not easily angered, ',
		'it keeps no record of wrongs. Love does not delight ',
		'in evil but rejoices with the truth. It always protects,',
		' always trusts, always hopes, always perseveres. ',
		'Love never fails.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'Love is patient, love is kind. It does not envy,',
		' it does not boast, it is not proud. It is not rude, it is not',
		' self-seeking, it is not easily angered,',
		'it keeps no record of wrongs. Love does not delight in evil but rejoices',
		'with the truth. It always protects,',
		' always trusts, always hopes, always perseveres.',
		'Love never fails.',
	]
	assert result_fn() == expected
}

fn test_prefix_str_option() {
	println(@METHOD)
	input := [
		'Prefix lines test',
		'',
		'> Effects present letters inquiry no an removed or friends. Desire behind latter me though in. ',
		'>   Supposing shameless am he engrossed up additions. My possible peculiar together to. ',
		'',
		'> Desire so better am cannot he up before points. Remember mistaken opinions it pleasure of debating. ',
		'> Court front maids forty if aware their at. Chicken use are pressed removed.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-p', '> ', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'Prefix lines test',
		'',
		'> Effects present letters inquiry no an removed or friends. Desire behind',
		'> latter me though in.',
		'>   Supposing shameless am he engrossed up additions. My possible peculiar',
		'>   together to.',
		'',
		'> Desire so better am cannot he up before points. Remember mistaken',
		'> opinions it pleasure of debating.  Court front maids forty if aware their',
		'> at. Chicken use are pressed removed.',
	]
	assert result_fn() == expected
}

fn test_uniform_spacing_option() {
	println(@METHOD)
	input := [
		'venenatis pede. Quisque dui     dui, ultricies ut, facilisis   non, pulvinar non. Duis         quis arcu a purus volutpat iaculis. Morbi id dui in    diam ornare',
	]
	tmp := to_tmp_file(input)
	// non-uniform case
	out_fn1, result_fn1 := setup()
	run_fmt(['fmt', tmp], out_fn1)
	expected1 := [
		'venenatis pede. Quisque dui     dui, ultricies ut, facilisis   non,',
		'pulvinar non. Duis         quis arcu a purus volutpat iaculis. Morbi id dui',
		'in    diam ornare',
	]
	assert result_fn1() == expected1

	// uniform spacing case
	out_fn2, result_fn2 := setup()
	run_fmt(['fmt', '-u', tmp], out_fn2)
	os.rm(tmp)!
	expected2 := [
		'venenatis pede. Quisque dui dui, ultricies ut, facilisis non, pulvinar non.',
		'Duis quis arcu a purus volutpat iaculis. Morbi id dui in diam ornare',
	]
	assert result_fn2() == expected2
}

fn test_uniform_spacing_with_prefix_and_width() {
	println(@METHOD)
	input := [
		'Prefix lines test',
		'',
		'> Effects present letters inquiry no an removed or friends. Desire behind latter me though in. ',
		'>   Supposing shameless am he engrossed up additions. My possible peculiar together to. ',
		'',
		'> Desire so better am cannot he up before points. Remember mistaken opinions it pleasure of debating. ',
		'> Court front maids forty if aware their at. Chicken use are pressed removed.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-u', '-p', '> ', '-w', '30', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'> Prefix lines test',
		'',
		'> Effects present letters',
		'> inquiry no an removed or',
		'> friends. Desire behind',
		'> latter me though in.',
		'>   Supposing shameless am he',
		'>   engrossed up additions. My',
		'>   possible peculiar together',
		'>   to.',
		'',
		'> Desire so better am cannot',
		'> he up before points.',
		'> Remember mistaken opinions',
		'> it pleasure of debating.',
		'> Court front maids forty if',
		'> aware their at. Chicken use',
		'> are pressed removed.',
	]
	assert result_fn() == expected
}

fn test_crown_and_uniform_options() {
	println(@METHOD)
	input := [
		'By default,    blank lines, spaces between words, and indentation are preserved in the output;',
		'    successive input lines with different indentation are not joined; tabs are expanded on input and',
		'introduced on output.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-c', '-u', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'By default, blank lines, spaces between words, and indentation are',
		'    preserved in the output; successive input lines with different',
		'    indentation are not joined; tabs are expanded on input and',
		'introduced on output.',
	]
	assert result_fn() == expected
}

fn test_tagged_and_width_options() {
	println(@METHOD)
	input := [
		'Now is the time for all good men to come to the aid of their country.',
		'',
		'Now is the time for all good men to come to the aid of their country.',
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-t', '-w', '40', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'Now is the time for all good men to come',
		'    to the aid of their country.',
		'',
		'Now is the time for all good men to come',
		'    to the aid of their country.',
	]
	assert result_fn() == expected
}

fn test_unicode_handling() {
	println(@METHOD)
	input := [
		"I can do without ⑰ lobsters, you know. Come on!' So they ⼘≺↩⌝⚙⠃ couldn't get them out again. The Mock Turtle went on again:-- 'I didn't mean it!' Ⓡpleaded.",
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-w', '40', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'I can do without ⑰ lobsters, you know.',
		"Come on!' So they ⼘≺↩⌝⚙⠃ couldn't get",
		'them out again. The Mock Turtle went on',
		"again:-- 'I didn't mean it!' Ⓡpleaded.",
	]
	assert result_fn() == expected
}

fn test_unicode__tab_handling() {
	println(@METHOD)
	input := [
		"I can do without ⑰ lobsters, \tyou know. Come on!' So they ⼘≺↩⌝⚙⠃ couldn't get them out again. The Mock Turtle went on again:-- 'I didn't mean it!' Ⓡpleaded.",
	]
	tmp := to_tmp_file(input)
	out_fn, result_fn := setup()
	run_fmt(['fmt', '-w', '40', tmp], out_fn)
	os.rm(tmp)!
	expected := [
		'I can do without ⑰ lobsters,    you',
		"know. Come on!' So they ⼘≺↩⌝⚙⠃ couldn't",
		'get them out again. The Mock Turtle went',
		"on again:-- 'I didn't mean it!'",
		'Ⓡpleaded.',
	]
	assert result_fn() == expected
}
