import os
import strings

const (
	buf_size     = 256
	newline_char = u8(10)
	nul_char     = u8(0)
	space_char   = u8(32)
)

struct HeadCommand {
	bytes_to_read   int
	lines_to_read   int
	silent          bool
	verbose         bool
	zero_terminated bool
}

fn write_header(name string, first_file bool) {
	prefix := if first_file { '' } else { '\n' }
	print('$prefix==> $name <==\n')
}

fn write_bytes(file_ptr os.File, num_bytes int) {
	mut m_bytes_to_write := num_bytes
	adj_buf_size := if num_bytes < buf_size { num_bytes } else { buf_size }
	mut output_buf := strings.new_builder(adj_buf_size)
	mut reading_buf := []u8{len: adj_buf_size}
	mut cursor := u64(0)

	defer {
		print(output_buf.str())
	}

	for m_bytes_to_write != 0 {
		read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { return }
		cursor += u64(read_bytes_num)

		if read_bytes_num == 0 { m_bytes_to_write = 0 } // reached end of file

		for i := 0; i < read_bytes_num; i++ {
			c := reading_buf[i]
			output_buf.write_u8(c)
			m_bytes_to_write--
		}
	}
}

fn write_lines(file_ptr os.File, num_lines int, delim_char u8) {
	mut m_lines_to_write := num_lines
	mut output_buf := strings.new_builder(buf_size)
	mut reading_buf := []u8{len: buf_size}
	mut cursor := u64(0)

	defer {
		print(output_buf.str())
	}

	for m_lines_to_write != 0 {
		read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { return }
		cursor += u64(read_bytes_num)

		if read_bytes_num == 0 { m_lines_to_write = 0 } // reached end of file

		for i := 0; i < read_bytes_num; i++ {
			c := reading_buf[i]
			output_buf.write_u8(c)
			if c == newline_char {
				m_lines_to_write--
			}
		}
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
	write_lines(file_ptr, c.lines_to_read, if c.zero_terminated { nul_char } else { newline_char })
}

fn (c HeadCommand) write_bytes(file_ptr os.File) {
	write_bytes(file_ptr, c.bytes_to_read)
}

fn (c HeadCommand) write(file_ptr os.File) {
	if c.lines_to_read > 0 && c.bytes_to_read == 0 {
		c.write_lines(file_ptr)
		return
	}
	c.write_bytes(file_ptr)
}

fn (c HeadCommand) run(mut files []InputFile) {
	for i, mut file in files {
		file.open() or {
			eprintln('$name: $err.msg()')
			continue
		}
		c.write_header(file.is_stdin, file.name, files.len > 1, i == 0)
		c.write(file.file_ptr)
	}
}
