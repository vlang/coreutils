module testing

// Every shape here is one a test in this repository actually writes, so the rules in
// split_args are pinned by something rather than by taste.
fn test_split_args_plain_words() {
	assert split_args('tool -a -b file') == ['tool', '-a', '-b', 'file']
	assert split_args('') == []string{}
	assert split_args('   ') == []string{}
}

fn test_split_args_runs_of_whitespace() {
	assert split_args('tool    -a\t\t-b\nfile') == ['tool', '-a', '-b', 'file']
	// comm_test.v writes this one
	assert split_args('comm --output-delimiter="|" f1 f2') ==
		['comm', '--output-delimiter=|', 'f1', 'f2']
}

fn test_split_args_quotes() {
	// timeout_test.v writes this one
	assert split_args('timeout --preserve-status 1 sh -c "exit 42"') ==
		['timeout', '--preserve-status', '1', 'sh', '-c', 'exit 42']
	// sum_test.v writes this one, where the backslash is a character and not an escape
	assert split_args("sum tr -d '\\r' f") == ['sum', 'tr', '-d', '\\r', 'f']
	// An empty quoted word is still a word
	assert split_args('tool "" x') == ['tool', '', 'x']
}

fn test_split_args_keeps_backslashes_in_paths() {
	// The reason this is not a shell: eating the backslash would take the volume off.
	path := r'C:\Users\me\coreutils\test.txt'
	assert split_args('cksum ${path}') == ['cksum', path]
	assert split_args('cksum "${path}"') == ['cksum', path]
}

// An unterminated quote is not an error: whatever followed becomes one word, so the
// test that made the mistake fails on the program's message.
fn test_split_args_unterminated_quote() {
	assert split_args('tool "two words') == ['tool', 'two words']
	assert split_args("tool 'one") == ['tool', 'one']
}
