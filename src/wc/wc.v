import os
import common
import sync
import arrays

// Adapted from:
// https://github.com/schicho/vwc
// https://ajeetdsouza.github.io/blog/posts/beating-c-with-70-lines-of-go/
// https://github.com/ajeetdsouza/blog-wc-go

const application_name = 'wc'
const buffer_size = 16 * 1024
const new_line = `\n`
const space = ` `
const tab = `\t`
const carriage_return = `\r`
const vertical_tab = `\v`
const form_feed = `\f`
const file_list_sep = '\x00'

struct FileChunk {
mut:
	prev_char_is_space bool
	buffer             []u8
	is_last_chunk      bool
}

struct Count {
mut:
	name            string
	line_count      u32
	word_count      u32
	byte_count      u32
	char_count      u32
	max_line_length u32
}

struct Pair {
mut:
	name string
	file os.File
}

fn get_count(chunk FileChunk, last_line_length u32) (Count, u32) {
	mut count := Count{'', 0, 0, 0, 0, 0}
	mut prev_char_is_space := chunk.prev_char_is_space
	mut line_length := last_line_length

	for b in chunk.buffer {
		match b {
			`\r` {
				continue
			} // TODO handle windows \r\n
			new_line {
				count.line_count++
				prev_char_is_space = true
				if line_length > count.max_line_length {
					count.max_line_length = line_length
				}
				line_length = 0
			}
			space, carriage_return, vertical_tab, form_feed {
				prev_char_is_space = true
				line_length++
			}
			tab {
				prev_char_is_space = true
				line_length += 8
			}
			else {
				if prev_char_is_space {
					prev_char_is_space = false
					count.word_count++
				}
				line_length++
			}
		}
	}

	if line_length > count.max_line_length {
		count.max_line_length = line_length
	}

	return count, line_length
}

fn is_space(b u8) bool {
	return b == new_line || b == space || b == tab || b == carriage_return || b == vertical_tab
		|| b == form_feed
}

struct FileReader {
mut:
	file               os.File
	last_char_is_space bool
	mutex              sync.Mutex
}

fn (mut file_reader FileReader) read_chunk(mut buffer []u8) ?FileChunk {
	file_reader.mutex.@lock()
	defer {
		file_reader.mutex.unlock()
	}

	nbytes := file_reader.file.read(mut buffer) or { return none } // Propagate error. Either EOF or read error.
	mut chunk := FileChunk{file_reader.last_char_is_space, buffer[..nbytes].clone(), false}
	file_reader.last_char_is_space = is_space(buffer[nbytes - 1])
	if nbytes < buffer.len {
		chunk.is_last_chunk = true
	}
	return chunk
}

fn file_reader_counter(mut file_reader FileReader) Count {
	mut buffer := []u8{len: buffer_size}
	mut total_count := Count{'', 0, 0, 0, 0, 0}
	mut count := Count{'', 0, 0, 0, 0, 0}
	mut line_length := u32(0)

	for {
		chunk := file_reader.read_chunk(mut buffer) or {
			match err {
				none {
					// EOF 'error', just break out of the loop.
					break
				}
				else {
					println(err)
				}
			}
			exit(1)
		}

		count, line_length = get_count(chunk, line_length)

		total_count.line_count += count.line_count
		total_count.word_count += count.word_count
		total_count.byte_count += u32(chunk.buffer.len)
		total_count.char_count += u32(chunk.buffer.bytestr().runes().len)
		if count.max_line_length > total_count.max_line_length {
			total_count.max_line_length = count.max_line_length
		}
	}

	return total_count
}

fn count_file(mut file os.File) Count {
	defer {
		file.close()
	}

	mut file_reader := &FileReader{file, true, sync.new_mutex()}
	return file_reader_counter(mut file_reader)
}

fn get_files(args []string) []Pair {
	if args.len == 0 || args[0] == '-' {
		return [Pair{'-', os.stdin()}]
	} else {
		mut files := []Pair{}
		for file_path in args {
			files << Pair{file_path, os.open(file_path) or {
				eprintln('${application_name}: ${file_path}: No such file or directory')
				exit(1)
			}}
		}
		return files
	}
}

fn get_file_names_from_list_file(list_file string) []string {
	return (os.read_file(list_file) or {
		eprintln('${application_name}: ${list_file}: error reading file - ${err}')
		exit(1)
	}).split(file_list_sep)
}

fn get_file_names_from_stdin_stream() []string {
	return os.get_line().split(file_list_sep)
}

fn rjust(s string, width int) string {
	if width == 0 {
		return s
	}
	return ' '.repeat(width - s.len) + s
}

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(application_name)
	fp.usage_example('[OPTION]... [FILE]...')
	fp.description('Print newline, word, and byte counts for each FILE, and a total line if more than one FILE is specified.')
	fp.description('A word is a non-zero-length sequence of characters delimited by white space.')
	fp.description('')
	fp.description('With no FILE, or when FILE is -, read standard input.')
	fp.description('')
	fp.description('The options below may be used to select which counts are printed, always in the following order: newline, word, character, byte, maximum line length.')

	mut bytes_opt := fp.bool('bytes', `c`, false, 'print the byte counts')
	chars_opt := fp.bool('chars', `m`, false, 'print the character counts')
	mut lines_opt := fp.bool('lines', `l`, false, 'print the newline counts')
	mut words_opt := fp.bool('words', `w`, false, 'print the words counts')
	maxline_opt := fp.bool('max-line-length', `L`, false, 'print the maximum display width')
	list_file := fp.string_opt('files0-from', 0, 'read input from the files specified by NUL-terminated names in file F; If F is - then read names from standard input') or {
		''
	}

	mut args := fp.finalize() or {
		eprintln(err)
		exit(1)
	}

	if list_file == '-' {
		args = get_file_names_from_stdin_stream()
	} else if list_file != '' {
		args = get_file_names_from_list_file(list_file)
	}
	args = args.filter(it.len > 0)
	if !bytes_opt && !chars_opt && !lines_opt && !words_opt && !maxline_opt {
		lines_opt = true
		words_opt = true
		bytes_opt = true
	}

	mut results := []Count{}
	for mut p in get_files(args) {
		mut count := count_file(mut p.file)
		count.name = p.name
		results << count
	}

	mut total_line_count := u32(0)
	mut total_word_count := u32(0)
	mut total_byte_count := u32(0)
	mut total_char_count := u32(0)
	mut max_line_length := u32(0)
	for res in results {
		total_line_count += res.line_count
		total_word_count += res.word_count
		total_byte_count += res.byte_count
		total_char_count += res.char_count
		if res.max_line_length > max_line_length {
			max_line_length = res.max_line_length
		}
	}

	total_line_count_len := total_line_count.str().len
	total_word_count_len := total_word_count.str().len
	total_byte_count_len := total_byte_count.str().len
	total_char_count_len := total_char_count.str().len
	max_line_length_len := max_line_length.str().len

	mut col_size := int(0)
	if byte(bytes_opt) + byte(chars_opt) + byte(lines_opt) + byte(words_opt) + byte(maxline_opt) == 1 {
		col_size = 0
	} else {
		if total_line_count_len > col_size {
			col_size = total_line_count_len
		}
		if total_word_count_len > col_size {
			col_size = total_word_count_len
		}
		if total_byte_count_len > col_size {
			col_size = total_byte_count_len
		}
		if total_char_count_len > col_size {
			col_size = total_char_count_len
		}
		if max_line_length_len > col_size {
			col_size = max_line_length_len
		}
	}

	min_col_size := arrays.max([total_line_count_len, total_word_count_len, total_byte_count_len,
		total_char_count_len, max_line_length_len]) or { panic(err) }
	if results.len > 1 && col_size < min_col_size {
		col_size = min_col_size
	}

	if list_file == '-' {
		col_size = 0
	}
	mut cols := []string{}
	for res in results {
		cols = []string{}
		if lines_opt {
			cols << rjust(res.line_count.str(), col_size)
		}
		if words_opt {
			cols << rjust(res.word_count.str(), col_size)
		}
		if bytes_opt {
			cols << rjust(res.byte_count.str(), col_size)
		}
		if chars_opt {
			cols << rjust(res.char_count.str(), col_size)
		}
		if maxline_opt {
			cols << rjust(res.max_line_length.str(), col_size)
		}
		if res.name != '-' {
			cols << res.name
		}
		print(cols.join(' '))
		print('\n')
	}

	if results.len > 1 {
		cols = []string{}
		if lines_opt {
			cols << rjust(total_line_count.str(), col_size)
		}
		if words_opt {
			cols << rjust(total_word_count.str(), col_size)
		}
		if bytes_opt {
			cols << rjust(total_byte_count.str(), col_size)
		}
		if chars_opt {
			cols << rjust(total_char_count.str(), col_size)
		}
		if maxline_opt {
			cols << rjust(max_line_length.str(), col_size)
		}
		cols << 'total'
		print(cols.join(' '))
		print('\n')
	}
}
