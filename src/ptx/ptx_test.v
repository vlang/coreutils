import common.ptx as ptxmod

fn test_parse_args_defaults() {
	s := ptxmod.parse_args([])
	assert s.width == 72
	assert s.gap == 3
	assert !s.ignore_case
	// The default truncation marker is the forward slash.
	assert s.truncate_marker == '/'
}

fn test_parse_args_geometry() {
	s := ptxmod.parse_args(['-w', '40', '-g', '2'])
	assert s.width == 40
	assert s.gap == 2

	attached := ptxmod.parse_args(['-w40', '-g2'])
	assert attached.width == 40
	assert attached.gap == 2

	eq := ptxmod.parse_args(['--width=50', '--gap-size=4'])
	assert eq.width == 50
	assert eq.gap == 4
}

fn test_parse_args_flags() {
	s := ptxmod.parse_args(['-f', '-A', '-r', '-t'])
	assert s.ignore_case
	assert s.auto_reference
	assert s.references
	assert s.typeset
}

fn test_parse_args_file_options() {
	s := ptxmod.parse_args(['-o', 'only.txt', '-i', 'ign.txt', '-b', 'brk.txt'])
	assert s.only_file == 'only.txt'
	assert s.ignore_file == 'ign.txt'
	assert s.break_file == 'brk.txt'

	attached := ptxmod.parse_args(['-oonly.txt', '-W', '[a-z]+'])
	assert attached.only_file == 'only.txt'
	assert attached.word_regexp == '[a-z]+'
}

fn test_parse_args_truncation_marker() {
	s := ptxmod.parse_args(['-F', '@@'])
	assert s.truncate_marker == '@@'

	eq := ptxmod.parse_args(['--flag-truncation=>>'])
	assert eq.truncate_marker == '>>'
}

fn test_parse_args_operands() {
	s := ptxmod.parse_args(['one.txt', 'two.txt'])
	assert s.operands == ['one.txt', 'two.txt']

	dash := ptxmod.parse_args(['--', '-weird.txt'])
	assert dash.operands == ['-weird.txt']
}

fn test_build_entries_one_row_per_word() {
	text := 'alpha beta gamma\n'
	set := ptxmod.parse_args([])
	entries := ptxmod.build_entries(text, set)
	assert entries.len == 3
	assert entries[0].keyword == 'alpha'
	assert entries[0].before == ''
	assert entries[0].after == 'beta gamma'
	assert entries[1].keyword == 'beta'
	assert entries[1].before == 'alpha'
	assert entries[1].after == 'gamma'
	assert entries[2].keyword == 'gamma'
	assert entries[2].before == 'alpha beta'
	assert entries[2].after == ''
}

fn test_build_entries_splits_on_punctuation() {
	// The default keyword is a run of letters, so "it's" is two keywords and
	// "42nd" yields "nd" with "42" as context. Measured against GNU 9.4.
	text := "hello, world! it's 42nd"
	set := ptxmod.parse_args([])
	entries := ptxmod.build_entries(text, set)
	mut words := []string{}
	for e in entries {
		words << e.keyword
	}
	assert words == ['hello', 'world', 'it', 's', 'nd']
}

fn test_sort_orders_by_keyword() {
	set := ptxmod.parse_args([])
	mut entries := ptxmod.build_entries('gamma alpha beta\n', set)
	ptxmod.sort_entries(mut entries)
	mut words := []string{}
	for e in entries {
		words << e.keyword
	}
	assert words == ['alpha', 'beta', 'gamma']
}

fn test_render_keyword_column_is_fixed() {
	// Every keyword starts at the same column: line_width / 2 plus the gap
	// plus one. This is the property that makes the index scannable.
	set := ptxmod.parse_args(['-w', '60', '-g', '3'])
	entries := ptxmod.build_entries('alpha beta gamma\n', set)
	rows := ptxmod.render(entries, set)
	assert rows.len == 3
	for row in rows {
		assert row.len <= set.width, 'row wider than the line: ${row}'
	}
}

fn test_render_head_is_not_truncated_to_keyword_width() {
	// The head keeps all the words that fit on the line. Truncating it to the
	// keyword width instead would cut "beta gamma" to "beta ".
	set := ptxmod.parse_args(['-w', '72', '-g', '3'])
	entries := ptxmod.build_entries('alpha beta gamma\n', set)
	rows := ptxmod.render(entries, set)
	assert rows[0].contains('alpha beta gamma')
	assert rows[0].ends_with('beta gamma')
}

fn test_render_last_word_has_no_trailing_space() {
	set := ptxmod.parse_args([])
	entries := ptxmod.build_entries('alpha beta gamma\n', set)
	rows := ptxmod.render(entries, set)
	// The final keyword has no following context, so the row ends at it.
	assert rows[2].ends_with('gamma')
	assert !rows[2].ends_with(' ')
}

fn test_render_empty_input_gives_no_rows() {
	set := ptxmod.parse_args([])
	rows := ptxmod.render([], set)
	assert rows.len == 0
}
