import os
import strings

const (
	buf_size     = 256
	newline_char = u8(10)
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
	adj_buf_size := if num_bytes < buf_size { num_bytes } else { buf_size }
	mut output_buf := strings.new_builder(adj_buf_size)
	mut reading_buf := []u8{len: adj_buf_size}
	mut cursor := u64(0)
	mut bytes_written := 0

	for {
		if bytes_written < num_bytes {
			read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { return }
			cursor += u64(read_bytes_num)

			for i := 0; i < read_bytes_num; i++ {
				c := reading_buf[i]
				output_buf.write_u8(c)
				bytes_written++
				if bytes_written == num_bytes {
					print(output_buf.str())
					output_buf.clear()
					return
				}
			}
		} else {
			break
		}
	}
}

fn write_lines(file_ptr os.File, num_lines int) {
	mut output_buf := strings.new_builder(buf_size)
	mut reading_buf := []u8{len: buf_size}
	mut cursor := u64(0)
	mut lines_written := 0

	for {
		if lines_written < num_lines {
			read_bytes_num := file_ptr.read_bytes_into(cursor, mut reading_buf) or { return }
			cursor += u64(read_bytes_num)

			for i := 0; i < read_bytes_num; i++ {
				c := reading_buf[i]
				output_buf.write_u8(c)
				if c == newline_char {
					lines_written++
					print(output_buf.str())
					output_buf.clear()
					if lines_written == num_lines { return }
				}
			}
		} else {
			break
		}
	}
}

fn (c HeadCommand) write_header(is_stdin bool, name string, multiple_files bool, first_file bool) {
	if is_stdin {
		return
	}

	if c.verbose && !c.silent {
		write_header(name, first_file)
		return
	}

	if !multiple_files {
		return
	}

	write_header(name, first_file)
}

fn (c HeadCommand) write_lines(file_ptr os.File) {
	write_lines(file_ptr, c.lines_to_read)
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
		file.open() or { eprintln('$name: $err.msg()') continue }
		c.write_header(file.is_stdin, file.name, files.len > 1, i == 0)
		c.write(file.file_ptr)
	}
}
