module main

fn p(msg string) {
	print('${msg:-50}')
}

fn pass() {
	println('✅')
}

fn print_lines(lines []string) {
	println(' ')
	println('-------------')
	for line in lines {
		println(line)
	}
}

fn test_basic_wrap() {
	p(@METHOD)
	output := run_fmt(['fmt', '-w', '30', 'testdata/simple.txt'])
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
	assert output == expected
	pass()
}

fn test_narrow_to_formatted() {
	p(@METHOD)
	output := run_fmt(['fmt', 'testdata/narrow.txt'])
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
	assert output == expected
	pass()
}

fn test_line_indents_denote_new_paragraph() {
	p(@METHOD)
	output := run_fmt(['fmt', '-w', '35', 'testdata/basic_indent.txt'])
	expected := [
		'This is a single line paragraph',
		'    because this line has a',
		'    different indent',
		'',
		'Otherwise these other lines',
		'comprise a simple multline',
		'paragraph.',
	]
	assert output == expected
	pass()
}

fn test_numbered_list_no_options() {
	p(@METHOD)
	output := run_fmt(['fmt', 'testdata/list.txt'])
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
	assert output == expected
	pass()
}

fn test_numbered_list_w_40() {
	p(@METHOD)
	output := run_fmt(['fmt', '-w', '40', 'testdata/list.txt'])
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
	assert output == expected
	pass()
}
