module main

import common
import os

const app_name = 'split'
const default_prefix = 'x'
const default_suffix_length = 2
const default_count = 1000

enum Mode {
	lines
	bytes
	line_bytes
}

struct Settings {
mut:
	mode          Mode   = .lines
	value         int    = default_count
	prefix        string = default_prefix
	suffix_length int    = default_suffix_length
	numeric       bool
	file          string = '-'
}

// The modes differ only in how they decide a piece is full. The names, the growth
// of the suffix past its last combination and the reporting of a failure are shared,
// so they are written once.
struct Splitter {
mut:
	settings   Settings
	file_index int
}

fn main() {
	settings := args() or {
		common.exit_with_error_message(app_name, err.msg())
	}
	run(settings) or {
		eprintln('${app_name}: ${err.msg()}')
		exit(1)
	}
}

fn run(settings Settings) !void {
	data := read_input(settings.file)!
	mut s := Splitter{
		settings: settings
	}
	s.split(data)!
}

fn (mut s Splitter) split(data string) !void {
	match s.settings.mode {
		.bytes {
			s.split_bytes(data)!
		}
		.line_bytes {
			s.split_line_bytes(data)!
		}
		.lines {
			s.split_lines(data)!
		}
	}
}

// split_bytes cuts where the byte count says, which can land in the middle of a
// line. Measured with -b 1 over 21 bytes: 21 files of one byte, the last holding
// whatever is left over.
fn (mut s Splitter) split_bytes(data string) !void {
	mut start := 0
	for start < data.len {
		mut end := start + s.settings.value
		if end > data.len {
			end = data.len
		}
		s.write(data[start..end])!
		start = end
	}
}

// split_line_bytes is the same cut with one difference: a line is never split, so a
// line that would not fit starts the next file instead. Measured with -C 4 over ten
// two byte lines, four lines to a file and the last two one to a file because
// "9\n10\n" is 5 bytes and does not fit; with -C 5 they share one file because it
// does. With -C 1, where no line can ever fit, GNU still writes them one to a file
// rather than nothing, which is what the last > start check is for.
fn (mut s Splitter) split_line_bytes(data string) !void {
	mut start := 0
	for start < data.len {
		mut end := start
		mut line_end := start
		for end < data.len {
			mut next := end
			for next < data.len && data[next] != `\n` {
				next++
			}
			if next < data.len {
				next++
			}
			if next - start > s.settings.value {
				if line_end > start {
					break
				}
				// Not even one line fits, and GNU does not refuse then: it cuts at
				// the limit instead. Measured with -C 1 over 21 bytes, where it
				// writes 21 one byte files, exactly what -b 1 gives, and cutting by
				// lines would have nowhere to put a two byte line.
				line_end = start + s.settings.value
				if line_end > data.len {
					line_end = data.len
				}
				end = line_end
				break
			}
			line_end = next
			end = next
		}
		if line_end <= start {
			break
		}
		s.write(data[start..line_end])!
		start = line_end
	}
}

// split_lines counts newlines, and a last line without one still counts: it is a
// line, and GNU writes it.
fn (mut s Splitter) split_lines(data string) !void {
	mut piece_start := 0
	mut lines := 0
	mut start := 0
	for start < data.len {
		mut end := start
		for end < data.len && data[end] != `\n` {
			end++
		}
		if end < data.len {
			end++
		}
		lines++
		start = end
		if lines == s.settings.value {
			s.write(data[piece_start..end])!
			piece_start = end
			lines = 0
		}
	}
	if lines > 0 {
		s.write(data[piece_start..data.len])!
	}
}

fn (mut s Splitter) write(data string) !void {
	name := s.next_name()
	mut file := os.create(name) or { return error('${name}: ${err.msg()}') }
	file.write_string(data) or { return error('${name}: ${err.msg()}') }
	file.close()
}

// next_name builds PREFIX plus a suffix of the requested width, the first being aa
// or 00, and the width grows when the combinations at the current width run out.
// That growth is what GNU does rather than failing: with -a 1 the names run
// xa..xz and then xaa, xab and onwards.
fn (mut s Splitter) next_name() string {
	mut alphabet := 26
	if s.settings.numeric {
		alphabet = 10
	}
	mut width := s.settings.suffix_length
	mut capacity := 1
	for width > 0 {
		capacity *= alphabet
		width--
	}
	mut index := s.file_index
	s.file_index++
	for index >= capacity {
		capacity *= alphabet
		s.settings.suffix_length++
	}
	mut out := []u8{len: s.settings.suffix_length}
	mut remaining := index
	for i := s.settings.suffix_length - 1; i >= 0; i-- {
		digit := remaining % alphabet
		remaining /= alphabet
		if s.settings.numeric {
			out[i] = u8(`0` + digit)
		} else {
			out[i] = u8(`a` + digit)
		}
	}
	return s.settings.prefix + out.bytestr()
}

// read_input reads the file up front, which the byte modes need because a cut can
// land anywhere in it, including inside a line.
fn read_input(path string) !string {
	if path == '-' {
		mut out := ''
		for {
			line := os.get_raw_line()
			if line.len == 0 {
				break
			}
			out += line
		}
		return out
	}
	if !os.exists(path) {
		return error("cannot open '${path}' for reading: No such file or directory")
	}
	return os.read_file(path)!
}

fn args() !Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description('Split a file into fixed-sized pieces.')

	lines := fp.int('lines', `l`, default_count, 'put at most COUNT lines into each output file')
	bytes := fp.int('bytes', `b`, -1, 'put at most SIZE bytes into each output file')
	line_bytes := fp.int('line-bytes', `C`, -1, 'put at most SIZE bytes into each output file, without breaking lines')
	suffix_length := fp.int('suffix-length', `a`, default_suffix_length, 'use SUFFIX characters for the file name suffix')
	numeric := fp.bool('numeric-suffixes', `d`, false, 'use numeric suffixes instead of alphabetic ones')
	// -n is recognised and refused rather than ignored, and both of its forms are
	// accepted by GNU, so this is a gap and not a match. The reason is written in the
	// pull request rather than guessed at here: neither form is a plain division,
	// and -n l/7 over ten lines and -n 7 over the same file both give 2,1,2,1,2,1,1
	// rather than the even split the word "chunks" suggests.
	chunks := fp.string('number', `n`, '', 'output N files; N may be l/K or r/N')

	rest := fp.remaining_parameters()

	// GNU refuses to be told how to cut in two different ways at once. Only the
	// options that differ from their defaults are counted, so asking for the default
	// alongside another way is taken here where GNU would refuse it.
	mut ways := 0
	mut set := Settings{}
	if lines != default_count {
		set.mode = .lines
		set.value = positive(lines, 'invalid number of lines')
		ways++
	}
	if bytes != -1 {
		set.mode = .bytes
		set.value = positive(bytes, 'invalid number of bytes')
		ways++
	}
	if line_bytes != -1 {
		set.mode = .line_bytes
		set.value = positive(line_bytes, 'invalid number of lines')
		ways++
	}
	if ways > 1 {
		return error('cannot split in more than one way')
	}
	if chunks != '' {
		return error('chunks are not implemented')
	}

	set.suffix_length = suffix_length
	if set.suffix_length < 1 {
		return error("invalid suffix length: '${suffix_length}'")
	}
	set.numeric = numeric

	mut position := 0
	if rest.len > 0 {
		set.file = rest[0]
		position = 1
	}
	if rest.len > 1 {
		set.prefix = rest[1]
		position = 2
	}
	if rest.len > 2 {
		return error("extra operand '${rest[2]}'")
	}
	if position == 1 {
		// A prefix of "x" is the default, and saying so out loud keeps a prefix the
		// user meant to write from being taken for the default one.
		set.prefix = default_prefix
	}
	if set.prefix.len == 0 {
		return error("invalid suffix length: '${suffix_length}'")
	}
	return set
}

fn positive(value int, complaint string) int {
	if value < 1 {
		return error_not_positive(value, complaint)
	}
	return value
}

// error_not_positive cannot be an or block inside the caller, which already has one,
// so it prints and leaves the way out to the caller rather than returning twice.
fn error_not_positive(value int, complaint string) int {
	eprintln("${app_name}: ${complaint}: '${value}'")
	exit(1)
	return 1
}
