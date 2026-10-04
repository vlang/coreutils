import os

// input_files is the list of inputs to read, which --files0-from can supply.
fn input_files(options Options) []string {
	mut files := options.files.clone()
	if options.files0_from.len > 0 {
		files = read_files0(options)
	}
	if files.len == 0 {
		files = ['-']
	}
	return files
}

// read_all_input gathers the lines from every input into one stream, which is what
// GNU sorts as a whole unless -m is given.
fn read_all_input(options Options) []InputLine {
	mut lines := []InputLine{}
	for file in input_files(options) {
		lines << read_one(file, options)
	}
	return lines
}

// read_each_input keeps the inputs apart, which -m needs in order to merge them
// rather than sort them.
fn read_each_input(options Options) [][]InputLine {
	mut all := [][]InputLine{}
	for file in input_files(options) {
		all << read_one(file, options)
	}
	return all
}

fn read_one(file string, options Options) []InputLine {
	mut f := if file == '-' {
		os.stdin()
	} else {
		os.open(file) or { read_error(file) }
	}
	return read_stream(f, file, options)
}

// read_files0 reads the list of names that --files0-from points at. The names are
// separated by NUL, so a name may contain a newline.
fn read_files0(options Options) []string {
	mut list := if options.files0_from == '-' {
		os.stdin()
	} else {
		os.open(options.files0_from) or { read_error(options.files0_from) }
	}
	content := read_all(list)
	mut names := []string{}
	mut start := 0
	mut i := 0
	for i < content.len {
		if content[i] == 0 {
			names << content[start..i]
			start = i + 1
		}
		i++
	}
	if start < content.len {
		names << content[start..]
	}
	return names
}

// read_stream splits a file into lines. A line keeps the text without its
// delimiter, and the position GNU reports it at.
fn read_stream(f os.File, name string, options Options) []InputLine {
	content := read_all(f)
	return split_records(content, name, line_delimiter(options))
}

// read_all reads a file to its end.
fn read_all(f os.File) string {
	mut out := []u8{}
	mut buf := []u8{len: 64 * 1024}
	for {
		n := f.read(mut buf) or { break }
		if n == 0 {
			break
		}
		out << buf[..n]
	}
	return out.bytestr()
}

// split_records cuts content at every delimiter byte.
fn split_records(content string, name string, delim string) []InputLine {
	mut lines := []InputLine{}
	mut start := 0
	mut i := 0
	mut number := 1
	for i < content.len {
		if content[i..i + delim.len] == delim {
			lines << InputLine{
				text:   content[start..i]
				file:   name
				number: number
				order:  lines.len
			}
			number++
			start = i + 1
		}
		i++
	}
	// A file that ends with a delimiter has no extra empty line, but a file that
	// does not ends with one line that has no delimiter.
	if start < content.len {
		lines << InputLine{
			text:   content[start..]
			file:   name
			number: number
			order:  lines.len
		}
	}
	return lines
}
