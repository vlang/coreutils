module main

fn print_lines(lines []string) {
	println(' ')
	println('-------------')
	for line in lines {
		println(line)
	}
}

fn test_basic_wrap() {
	println(@METHOD)
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
}

fn test_narrow_to_formatted() {
	println(@METHOD)
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
}

fn test_line_indents_denote_new_paragraph() {
	println(@METHOD)
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
}

fn test_numbered_list_no_options() {
	println(@METHOD)
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
}

fn test_numbered_list_w_40() {
	println(@METHOD)
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
}

fn test_split_only() {
	println(@METHOD)
	output := run_fmt(['fmt', '-s', 'testdata/lorum_ipsum.txt'])
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
	assert output == expected
}

fn test_indents_no_blank_lines() {
	println(@METHOD)
	output := run_fmt(['fmt', 'testdata/poem.txt'])
	expected := [
		'Love is patient, love is kind. It does not envy,',
		' it does not boast, it is not proud. It is not rude, it is not',
		' self-seeking, it is not easily angered,',
		'it keeps no record of wrongs. Love does not delight in evil but rejoices',
		'with the truth. It always protects,',
		' always trusts, always hopes, always perseveres.',
		'Love never fails.',
	]
	assert output == expected
}

fn test_prefix_str_option() {
	println(@METHOD)
	output := run_fmt(['fmt', '-p', '> ', 'testdata/prefix.txt'])
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
	assert output == expected
}

fn test_uniform_spacing_option() {
	println(@METHOD)
	// non-uniform case
	output1 := run_fmt(['fmt', 'testdata/not_uniform_spacing.txt'])
	expected1 := [
		'venenatis pede. Quisque dui     dui, ultricies ut, facilisis   non,',
		'pulvinar non. Duis         quis arcu a purus volutpat iaculis. Morbi id dui',
		'in    diam ornare',
	]
	assert output1 == expected1

	// uniform spacing case
	output2 := run_fmt(['fmt', '-u', 'testdata/not_uniform_spacing.txt'])
	expected2 := [
		'venenatis pede. Quisque dui dui, ultricies ut, facilisis non, pulvinar non.',
		'Duis quis arcu a purus volutpat iaculis. Morbi id dui in diam ornare',
	]
	assert output2 == expected2
}

fn test_uniform_spacing_with_prefix_and_width() {
	println(@METHOD)
	output := run_fmt(['fmt', '-u', '-p', '> ', '-w', '30', 'testdata/prefix.txt'])
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
	assert output == expected
}

fn test_crown_and_uniform_options() {
	println(@METHOD)
	output := run_fmt(['fmt', '-c', '-u', 'testdata/crown.txt'])
	expected := [
		'By default, blank lines, spaces between words, and indentation are',
		'    preserved in the output; successive input lines with different',
		'    indentation are not joined; tabs are expanded on input and',
		'introduced on output.',
	]
	assert expected == output
}
