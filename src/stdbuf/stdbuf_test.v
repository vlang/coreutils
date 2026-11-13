import common.stdbuf

fn test_parse_args_defaults() {
	s := stdbuf.parse_args([])
	assert s.modes.len == 0
	assert s.command.len == 0
}

fn test_parse_args_line_mode() {
	// -oL is the line-buffered spelling.
	s := stdbuf.parse_args(['-oL', 'cat'])
	assert s.modes.len == 1
	assert s.modes[0].stream == .output
	assert s.modes[0].mode == .line
	assert s.command == ['cat']
}

fn test_parse_args_unbuffered() {
	s := stdbuf.parse_args(['-o0', 'cat'])
	assert s.modes.len == 1
	assert s.modes[0].mode == .unbuffered
	assert s.modes[0].size == 0
}

fn test_parse_args_byte_count() {
	s := stdbuf.parse_args(['-o', '4096', 'cat'])
	assert s.modes.len == 1
	assert s.modes[0].mode == .bytes
	assert s.modes[0].size == 4096
}

fn test_parse_args_size_suffixes() {
	s := stdbuf.parse_args(['-o', '1K', 'cat'])
	assert s.modes[0].size == 1024

	m := stdbuf.parse_args(['-o', '1M', 'cat'])
	assert m.modes[0].size == 1024 * 1024

	g := stdbuf.parse_args(['-o', '1G', 'cat'])
	assert g.modes[0].size == 1024 * 1024 * 1024
}

fn test_parse_args_all_three_streams() {
	s := stdbuf.parse_args(['-i0', '-oL', '-e0', 'cat'])
	assert s.modes.len == 3
	assert s.modes[0].stream == .input
	assert s.modes[1].stream == .output
	assert s.modes[2].stream == .error
	assert s.command == ['cat']
}

fn test_parse_args_separate_value() {
	// The value may be its own argument as well as attached.
	s := stdbuf.parse_args(['-o', 'L', 'cat', 'arg'])
	assert s.modes[0].mode == .line
	assert s.command == ['cat', 'arg']
}

fn test_parse_args_command_with_arguments() {
	s := stdbuf.parse_args(['-o0', 'printf', '%s', 'x'])
	assert s.command == ['printf', '%s', 'x']
}

fn test_parse_args_double_dash() {
	// Everything after -- is the command even when it looks like an option.
	s := stdbuf.parse_args(['-o0', '--', '-weird-cmd'])
	assert s.command == ['-weird-cmd']
}
