module fmt

fn print_it(lines []string) {
	for line in lines {
		println(line)
	}
}

fn test_basic_wrap() {
	output := run_fmt(['fmt', '-w', '30', 'simple.txt'])
	// print_it(output)
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
