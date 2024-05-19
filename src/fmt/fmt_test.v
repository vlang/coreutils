module fmt

fn p(msg string) {
	print('${msg:-50}')
}

fn pass() {
	println('✅')
}

fn print_lines(lines []string) {
	for line in lines {
		println(line)
	}
}

fn test_basic_wrap() {
	p(@METHOD)
	output := run_fmt(['fmt', '-w', '30', 'simple.txt'])
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
