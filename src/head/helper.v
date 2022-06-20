import common
import os
import strings

const (
	name = 'head'
)

// Print messages and exit
[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

struct InputFile {
	is_stdin bool
	name string
mut:
	is_open bool
	file_ptr os.File
}

fn (mut f InputFile) open() ? {
	if f.is_stdin { return }
	f.file_ptr = os.open(f.name) or { return err }
	f.is_open = true
}

fn (mut f InputFile) close() {
	f.file_ptr.close()
	f.is_open = false
}

fn get_files(file_args []string) []InputFile {
	mut files := []InputFile{}
	if file_args.len == 0 || file_args[0] == '-' {
		files << InputFile{is_stdin:true, name: 'stdin', file_ptr:os.stdin()}
		return files
	}

	for _, fa in file_args {
		files << InputFile{is_stdin:false, name: fa}
	}
	return files
}

fn wrap_long_command_description(description string, max_cols int) string {
	mut buf := strings.new_builder(buf_size)
	if description.len <= max_cols {
		return description
	}

	mut last_c := u8(0)
	mut pending_split := false
	for i, c in description {
		if i > 1 && i % max_cols == 0 {
			pending_split = true
		}

		if pending_split && last_c == space_char {
			buf.write_string('\n\t\t\t\t')
			pending_split = false
		}
		buf.write_u8(c)
		last_c = c
	}

	return buf.str()
}

fn setup_command(args []string) ?(HeadCommand, []InputFile) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.usage_example('[OPTION]... [FILE]...')
	fp.description('Wrap input lines in each FILE, writing to standard output.')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	bytes := fp.int('bytes', `c`, 0, wrap_long_command_description("print the first NUM bytes of each file: with the leading '-', print all but the last NUM bytes of each file", 45))
	lines := fp.int('lines', `n`, 10, wrap_long_command_description("print the first NUM lines instead of the first 10: with the leading '-' print all but the last NUM lines of each file", 48))
	verbose := fp.bool('verbose', `v`, false, 'always print headers giving file names')
	silent := fp.bool('silent', `q`, false, 'never print headers giving file names')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('$name $common.coreutils_version()')
	}

	file_args := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }

	return HeadCommand{
		bytes_to_read: bytes
		lines_to_read: lines
		silent: silent
		verbose: verbose
		zero_terminated: zero_terminated
	}, get_files(file_args)
}

fn run_head(args []string) {
	head, mut files := setup_command(args) or {
		common.exit_with_error_message(name, err.msg())
	}

	head.run(mut files)
}
