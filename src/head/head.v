import os
import common
import strings
import io

const name = 'head'
const buf_size = 256
const newline_char = u8(10)
const nul_char = u8(0)
const space_char = u8(32)

struct HeadCommand {
	bytes_to_read   int
	lines_to_read   int
	silent          bool
	verbose         bool
	zero_terminated bool
}

fn write_header(name string, first_file bool) {
	prefix := if first_file { '' } else { '\n' }
	print('${prefix}==> ${name} <==\n')
}

@[direct_array_access]
fn write_bytes(file_ptr os.File, num_bytes int) {
	mut m_bytes_to_write := num_bytes
	adj_buf_size := if num_bytes < buf_size { num_bytes } else { buf_size }
	mut output_buf := strings.new_builder(adj_buf_size)
	mut reading_buf := []u8{len: adj_buf_size}
	mut cursor := u64(0)

	for m_bytes_to_write != 0 {
		read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { break }
		cursor += u64(read_bytes_num)

		if read_bytes_num == 0 {
			m_bytes_to_write = 0
		}
		// reached end of file

		for i := 0; i < read_bytes_num; i++ {
			c := reading_buf[i]
			output_buf.write_u8(c)
			m_bytes_to_write--
			print(output_buf.str())
			output_buf.clear()
			if m_bytes_to_write == 0 {
				break
			}
		}
	}

	print(output_buf.str())
}

fn write_bytes_upto_max(file_ptr os.File, num_bytes int) {
	mut output_buf := strings.new_builder(buf_size)
	mut reading_buf := []u8{len: buf_size}
	mut cursor := u64(0)

	for {
		read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { break }
		cursor += u64(read_bytes_num)

		if read_bytes_num == 0 {
			break
		}
		// reached end of file

		for i := 0; i < read_bytes_num; i++ {
			c := reading_buf[i]
			output_buf.write_u8(c)
		}
	}

	mut back_to_lookup := output_buf.len + num_bytes
	if back_to_lookup < 0 {
		output_buf.clear()
	} else {
		output_buf.go_back_to(back_to_lookup)
	}

	print(output_buf.str())
}

@[direct_array_access]
fn write_lines(file os.File, num_lines int, delim_char u8) {
	mut m_lines_to_write := num_lines
	mut f_reader := io.new_buffered_reader(reader: file)
	mut output_buf := strings.new_builder(buf_size)
	mut reading_buf := []u8{len: buf_size}

	for m_lines_to_write != 0 {
		read_bytes_num := f_reader.read(mut reading_buf) or {
			m_lines_to_write = 0
			continue
		}
		if read_bytes_num == 0 {
			m_lines_to_write = 0
		}
		// reached end of file

		for i := 0; i < read_bytes_num; i++ {
			c := reading_buf[i]
			output_buf.write_u8(c)
			if c == delim_char {
				m_lines_to_write--
				print(output_buf.str())
				output_buf.clear()
				if m_lines_to_write == 0 {
					break
				}
			}
		}
	}

	output_buf.str()
}

fn write_lines_upto_max(file_ptr os.File, num_lines int, delim_char u8) {
	mut output_buf := strings.new_builder(buf_size)
	mut reading_buf := []u8{len: buf_size}
	mut cursor := u64(0)
	mut lines_count := 0
	mut read_cursor := 0
	mut delim_positions := []int{}

	defer {
		print(output_buf.str())
	}

	for {
		read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { break }
		cursor += u64(read_bytes_num)

		if read_bytes_num == 0 {
			break
		}
		// reached end of file

		for i := 0; i < read_bytes_num; i++ {
			read_cursor++
			c := reading_buf[i]
			output_buf.write_u8(c)
			if c == delim_char {
				lines_count++
				delim_positions << read_cursor
			}
		}
	}

	mut back_to_lookup := delim_positions.len + (num_lines - 1)
	if back_to_lookup >= delim_positions.len {
		back_to_lookup = delim_positions.len
	}
	if back_to_lookup < 0 {
		output_buf.clear()
	} else {
		output_buf.go_back_to(delim_positions[back_to_lookup])
	}
}

fn (c HeadCommand) write_header(is_stdin bool, name string, multiple_files bool, first_file bool) {
	if is_stdin || c.silent {
		return
	}

	if c.verbose {
		write_header(name, first_file)
		return
	}

	if !multiple_files {
		return
	}

	write_header(name, first_file)
}

fn (c HeadCommand) write_lines(file_ptr os.File) {
	delim := if c.zero_terminated { nul_char } else { newline_char }
	if c.lines_to_read < 0 {
		write_lines_upto_max(file_ptr, c.lines_to_read, delim)
		return
	}
	write_lines(file_ptr, c.lines_to_read, delim)
}

fn (c HeadCommand) write_bytes(file_ptr os.File) {
	if c.bytes_to_read < 0 {
		write_bytes_upto_max(file_ptr, c.bytes_to_read)
		return
	}
	write_bytes(file_ptr, c.bytes_to_read)
}

fn (c HeadCommand) write(file_ptr os.File) {
	if c.lines_to_read != 0 && c.bytes_to_read == 0 {
		c.write_lines(file_ptr)
		return
	}
	c.write_bytes(file_ptr)
}

fn (c HeadCommand) run(mut files []InputFile) {
	mut open_fails_num := 0
	for i, mut file in files {
		file.open() or {
			eprintln('${name}: ${err.msg()}')
			open_fails_num++
			continue
		}
		c.write_header(file.is_stdin, file.name, files.len > 1, i == 0)
		c.write(file.file_ptr)
		file.close()
	}
	if open_fails_num == files.len {
		exit(1)
	}
}

// Print messages and exit
@[noreturn]
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

fn (mut f InputFile) open() ! {
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
			name:     'stdin'
			file_ptr: os.stdin()
		}
		return files
	}

	for _, fa in file_args {
		files << InputFile{
			is_stdin: false
			name:     fa
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

fn setup_command(args []string) ?(HeadCommand, []InputFile) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.usage_example('[OPTION]... [FILE]...')
	fp.description('Wrap input lines in each FILE, writing to standard output.')
	fp.description('With no FILE, or when FILE is -, read standard input.')

	bytes := fp.int('bytes', `c`, 0, wrap_long_command_description("print the first NUM bytes of each file: with the leading '-', print all but the last NUM bytes of each file",
		45))
	lines := fp.int('lines', `n`, 10, wrap_long_command_description("print the first NUM lines instead of the first 10: with the leading '-' print all but the last NUM lines of each file",
		48))
	verbose := fp.bool('verbose', `v`, false, 'always print headers giving file names')
	silent := fp.bool('silent', `q`, false, 'never print headers giving file names')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('${name} ${common.coreutils_version()}')
	}

	file_args := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }

	return HeadCommand{
		bytes_to_read:   bytes
		lines_to_read:   lines
		silent:          silent
		verbose:         verbose
		zero_terminated: zero_terminated
	}, get_files(file_args)
}

fn run_head(args []string) {
	head, mut files := setup_command(args) or { common.exit_with_error_message(name, err.msg()) }

	head.run(mut files)
}

fn main() {
	run_head(os.args)
	//
}
