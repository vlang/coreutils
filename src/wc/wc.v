import os
import common
import sync
import runtime

// Adapted from:
// https://github.com/schicho/vwc
// https://ajeetdsouza.github.io/blog/posts/beating-c-with-70-lines-of-go/
// https://github.com/ajeetdsouza/blog-wc-go

const (
	application_name = 'wc'
	buffer_size      = 16 * 1024
	new_line         = `\n`
	space            = ` `
	tab              = `\t`
	carriage_return  = `\r`
	vertical_tab     = `\v`
	form_feed        = `\f`
)

struct FileChunk {
mut:
	prev_char_is_space bool
	buffer             []byte
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

fn get_count(chunk FileChunk) Count {
	mut count := Count{'', 0, 0, 0, 0, 0}
	mut prev_char_is_space := chunk.prev_char_is_space
	mut line_length := u32(0)

	for b in chunk.buffer {
		match b {
			new_line {
				count.line_count++
				prev_char_is_space = true
				if line_length > count.max_line_length {
					count.max_line_length = line_length
				}
				line_length = 0
			}
			space, tab, carriage_return, vertical_tab, form_feed {
				prev_char_is_space = true
				line_length++
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

	return count
}

fn is_space(b byte) bool {
	return b == new_line || b == space || b == tab || b == carriage_return || b == vertical_tab
		|| b == form_feed
}

struct FileReader {
mut:
	file               os.File
	last_char_is_space bool
	mutex              sync.Mutex
}

fn (mut file_reader FileReader) read_chunk(mut buffer []byte) ?FileChunk {
	file_reader.mutex.@lock()
	defer {
		file_reader.mutex.unlock()
	}

	nbytes := file_reader.file.read(mut buffer) ? // Propagate error. Either EOF or read error.
	chunk := FileChunk{file_reader.last_char_is_space, buffer[..nbytes]}
	file_reader.last_char_is_space = is_space(buffer[nbytes - 1])
	return chunk
}

fn file_reader_counter(mut file_reader FileReader, counts chan Count) {
	mut buffer := []byte{len: buffer_size}
	mut total_count := Count{'', 0, 0, 0, 0, 0}

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

		count := get_count(chunk)

		total_count.line_count += count.line_count
		total_count.word_count += count.word_count
		total_count.byte_count += u32(chunk.buffer.len)
		total_count.char_count += u32(chunk.buffer.bytestr().runes().len)
		if count.max_line_length > total_count.max_line_length {
			total_count.max_line_length = count.max_line_length
		}
	}

	counts <- total_count
}

fn count_file(mut file os.File) Count {
	defer {
		file.close()
	}

	mut file_reader := &FileReader{file, true, sync.new_mutex()}
	counts := chan Count{}
	num_workers := runtime.nr_cpus()

	for i := 0; i < num_workers; i++ {
		go file_reader_counter(mut file_reader, counts)
	}

	mut total_count := Count{'', 0, 0, 0, 0, 0}

	for i := 0; i < num_workers; i++ {
		count := <-counts
		total_count.line_count += count.line_count
		total_count.word_count += count.word_count
		total_count.byte_count += count.byte_count
		total_count.char_count += count.char_count
		if count.max_line_length > total_count.max_line_length {
			total_count.max_line_length = count.max_line_length
		}
	}
	counts.close()

	return total_count
}

fn get_files(args []string) map[string]os.File {
	if args.len == 0 || args[0] == '-' {
		return {
			'-': os.stdin()
		}
	} else {
		mut files := map[string]os.File{}
		for file_path in args {
			files[file_path] = os.open(file_path) or {
				eprintln('$application_name: $file_path: No such file or directory')
				exit(1)
			}
		}
		return files
	}
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

	args := fp.finalize() or {
		eprintln(err)
		exit(1)
	}

	if !bytes_opt && !chars_opt && !lines_opt && !words_opt && !maxline_opt {
		lines_opt = true
		words_opt = true
		bytes_opt = true
	}

	mut results := []Count{}
	for name, mut file in get_files(args) {
		mut count := count_file(mut file)
		count.name = name
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

	mut col_size := int(0)
	if byte(bytes_opt) + byte(chars_opt) + byte(lines_opt) + byte(words_opt) + byte(maxline_opt) == 1 {
		col_size = 0
	} else {
		if total_line_count.str().len > col_size {
			col_size = total_line_count.str().len
		}
		if total_word_count.str().len > col_size {
			col_size = total_word_count.str().len
		}
		if total_byte_count.str().len > col_size {
			col_size = total_byte_count.str().len
		}
		if total_char_count.str().len > col_size {
			col_size = total_char_count.str().len
		}
		if max_line_length.str().len > col_size {
			col_size = max_line_length.str().len
		}
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
			cols << rjust(total_line_count.str(), total_line_count.str().len)
		}
		if words_opt {
			cols << rjust(total_word_count.str(), total_word_count.str().len)
		}
		if bytes_opt {
			cols << rjust(total_byte_count.str(), total_byte_count.str().len)
		}
		if chars_opt {
			cols << rjust(total_char_count.str(), total_char_count.str().len)
		}
		if maxline_opt {
			cols << rjust(max_line_length.str(), max_line_length.str().len)
		}
		cols << 'total'
		print(cols.join(' '))
		print('\n')
	}
}
