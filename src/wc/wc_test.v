import os
import common.testing

const the_executable = testing.prepare_executable('wc')

const cmd = testing.new_paired_command('wc', the_executable)

fn test_help_and_version() ? {
	cmd.ensure_help_and_version_options_work() ?
}

fn test_abcd() {
	res := os.execute('$the_executable abcd')
	assert res.exit_code == 1
	assert res.output.trim_space() == 'wc: abcd: No such file or directory'
}

fn test_default() {
	mut f := os.open_file('textfile', 'w') or { panic(err) }
	f.write_string('Hello World!\nHow are you?') or {}
	f.close()
	defer {
		os.rm('textfile') or { panic(err) }
	}

	res := os.execute('$the_executable textfile')
	assert res.exit_code == 0
	assert res.output == ' 1  5 25 textfile\n'
}

fn test_max_line_length() {
	mut f := os.open_file('textfile', 'w') or { panic(err) }
	f.write_string('Hello World!\nHow are you?') or {}
	f.close()
	defer {
		os.rm('textfile') or { panic(err) }
	}

	res := os.execute('$the_executable -L textfile')
	assert res.exit_code == 0
	assert res.output == '12 textfile\n'
}

fn test_char_count() {
	mut f := os.open_file('textfile', 'w') or { panic(err) }
	f.write_string('Hello World!\nHow are you?') or {}
	f.close()
	defer {
		os.rm('textfile') or { panic(err) }
	}

	res := os.execute('$the_executable -m textfile')
	assert res.exit_code == 0
	assert res.output == '25 textfile\n'
}
