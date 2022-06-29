import os
import common
import strings

const (
	name         = 'fold'
	buf_size     = 256
	eof          = -1
	newline_char = `\n`
	nul_char     = `\0`
	back_char    = `\b`
	return_char  = `\r`
	tab_char     = `\t`
	space_char   = u8(32)
	tab_width    = 8
)

struct Folder {
	max_width       int
	count_bytes     bool
	break_at_spaces bool
mut:
	output_buf     strings.Builder
	pending_output []u8
	column         int
}

fn new_folder(width int, count_bytes bool, break_at_spaces bool) Folder {
	return Folder{
		max_width: width
		count_bytes: count_bytes
		break_at_spaces: break_at_spaces
		output_buf: strings.new_builder(buf_size)
	}
}

fn (mut f Folder) write_char(c int) ? {
	if c == common.eof {
		f.flush()?
		return
	}

	u_c := u8(c)
	f.pending_output << u_c

	if u_c == newline_char {
		f.flush()?
		return
	}

	f.column = adjust_column(f.column, u_c, f.count_bytes)
	if f.column > f.max_width {
		if f.break_at_spaces {
			f.break_on_last_space()?
			return
		}
		f.move_last_c_to_newline()?
	}
}

fn (mut f Folder) break_on_last_space() ? {
	mut last_found_space := 0
	for i := f.pending_output.len - 1; i >= 0; i-- {
		if f.pending_output[i] == space_char {
			last_found_space = i
			break
		}
	}

	pending_output_cpy := f.pending_output.clone()
	pre_space := pending_output_cpy[..last_found_space]
	post_space := pending_output_cpy[last_found_space + 1..]
	f.pending_output = pre_space

	f.flush()?

	f.write_char(int(newline_char))?
	for c in post_space {
		f.write_char(c)?
	}
}

fn (mut f Folder) move_last_c_to_newline() ? {
	last_written_c := f.pending_output.pop()
	f.pending_output << newline_char
	f.flush()?
	f.write_char(last_written_c)?
}

fn (mut f Folder) flush() ? {
	f.output_buf.write(f.pending_output)?
	f.pending_output.clear()
	f.column = 0
}

fn (mut f Folder) str() string {
	return f.output_buf.str()
}

struct FoldCommand {
	max_col_width                    int
	break_at_spaces                  bool
	count_bytes_ignore_control_chars bool
}

fn adjust_column(column int, c u8, count_bytes bool) int {
	if count_bytes {
		return column + 1
	}

	return match c {
		back_char {
			if column > 0 {
				column - 1
			} else {
				0
			}
		}
		return_char {
			0
		}
		tab_char {
			column + tab_width - column % tab_width
		}
		else {
			column + 1
		}
	}
}

fn fold_content_to_fit_within_width(file_ptr os.File, width int, count_bytes bool, break_at_spaces bool) {
	mut folder := new_folder(width, count_bytes, break_at_spaces)

	defer {
		println(folder.str())
	}

	mut b_reader := common.new_file_byte_reader(file_ptr)
	for b_reader.has_next() {
		c := b_reader.next()

		folder.write_char(c) or { panic('unable to write $c') }
	}
}

fn (c FoldCommand) run(mut files []InputFile) {
	mut open_fails_num := 0
	for mut file in files {
		file.open() or {
			eprintln('$name: $err.msg()')
			open_fails_num++
			continue
		}
		fold_content_to_fit_within_width(file.file_ptr, c.max_col_width, c.count_bytes_ignore_control_chars,
			c.break_at_spaces)
		file.close()
	}
	if open_fails_num == files.len {
		exit(1)
	}
}

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
	name     string
mut:
	is_open  bool
	file_ptr os.File
}

fn (mut f InputFile) open() ? {
	if f.is_stdin {
		return
	}
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
		files << InputFile{
			is_stdin: true
			name: 'stdin'
			file_ptr: os.stdin()
		}
		return files
	}

	for _, fa in file_args {
		files << InputFile{
			is_stdin: false
			name: fa
		}
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

fn setup_command(args []string) ?(FoldCommand, []InputFile) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.usage_example('[OPTION]... [FILE]...')
	fp.description('Wrap input lines in each FILE, writing to standard output.')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	bytes := fp.bool('bytes', `b`, false, 'count bytes rather than columns')
	spaces := fp.bool('spaces', `s`, false, 'break at spaces')
	width := fp.int('width', `w`, 80, 'use WIDTH columns instead of 80')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('$name $common.coreutils_version()')
	}

	file_args := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }

	return FoldCommand{
		max_col_width: width
		break_at_spaces: spaces
		count_bytes_ignore_control_chars: bytes
	}, get_files(file_args)
}

fn run_fold(args []string) {
	fold, mut files := setup_command(args) or { common.exit_with_error_message(name, err.msg()) }

	fold.run(mut files)
}

fn main() {
	run_fold(os.args)
	//
}
