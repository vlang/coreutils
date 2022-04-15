module main

import os
import io
import rand
import common

const (
	app_name        = 'shuf'
	app_description = 'Shuffles its input by outputting a random permutation of its input lines'
)

struct Settings {
	echo            bool
	input_range     string
	head_count      int
	output          string
	random_source   string
	repeat          bool
	zero_terminated bool
	fnames          []string
}

// main
fn main() {
	shuf(args())
}

fn shuf(settings Settings) {
	mut lines := []string{}

	lines = set_lines(lines.clone(), settings)
	lines = shuffle_lines(lines, settings)

	if settings.repeat {
		if settings.output.len > 0 {
			mut file := os.open_file(settings.output, 'w+', 0o666) or { panic(err) }
			for {
				output_lines_file(lines, settings, mut file)
			}
			file.close()
		} else {
			for {
				output_lines(lines, settings)
			}
		}
	} else {
		if settings.output.len > 0 {
			mut file := os.open_file(settings.output, 'w+', 0o666) or { panic(err) }
			output_lines_file(lines, settings, mut file)
			file.close()
		} else {
			output_lines(lines, settings)
		}
	}
}

fn output_lines(lines []string, settings Settings) {
	for i in 0 .. lines.len {
		if settings.head_count > 0 && i >= settings.head_count {
			break
		}
		if settings.zero_terminated {
			print(lines[i])
		} else {
			println(lines[i])
		}
	}
}

fn output_lines_file(lines []string, settings Settings, mut file os.File) {
	for i in 0 .. lines.len {
		if settings.head_count > 0 && i >= settings.head_count {
			break
		}
		if settings.zero_terminated {
			file.write_string('${lines[i]}') or { panic(err) }
		} else {
			file.write_string('${lines[i]}\n') or { panic(err) }
		}
	}
}

fn shuffle_lines(lines []string, settings Settings) []string {
	mut new_lines := lines.clone()
	if settings.random_source.len > 0 {
		mut file := os.File{}
		file = os.open(settings.random_source) or {
			eprintln('$app_name: $settings.random_source: No such file')
			exit(1)
		}
		mut bytes := io.read_all(io.ReadAllConfig{ reader: file, read_to_end_of_stream: true }) or {
			eprintln('$app_name: $settings.random_source: Can\'t read file')
			exit(1)
		}
		mut seed := u32(0)
		for b in bytes {
			seed += b.hex().u32()
		}
		rand.seed([u32(0), seed])

		for i in 0 .. new_lines.len {
			tmp := new_lines[i]
			random := rand.intn(new_lines.len)
			new_lines[i] = new_lines[random]
			new_lines[random] = tmp
		}
	} else {
		for i in 0 .. new_lines.len {
			tmp := new_lines[i]
			random := rand.intn(new_lines.len)
			new_lines[i] = new_lines[random]
			new_lines[random] = tmp
		}
	}

	return new_lines
}

fn set_lines(lines []string, settings Settings) []string {
	mut new_lines := lines.clone()
	mut fnames := settings.fnames
	input_range := settings.input_range.split('-')
	if input_range.len == 2 {
		for i in input_range[0].int() .. input_range[1].int() + 1 {
			new_lines << i.str()
		}
	} else {
		if fnames.len < 1 {
			fnames = ['-']
		}

		for fname in fnames {
			if settings.echo {
				new_lines << fname
			} else {
				new_lines = register_lines_by_file(new_lines.clone(), fname, settings.zero_terminated)
			}
		}
	}

	return new_lines
}

fn register_lines_by_file(lines []string, fname string, zero_terminated bool) []string {
	mut new_lines := lines.clone()
	mut file := os.File{}
	if fname == '-' {
		file = os.stdin()
	} else {
		file = os.open(fname) or {
			eprintln('$app_name: $fname: No such file or directory')
			exit(1)
		}
	}

	if zero_terminated {
		mut bytes := io.read_all(io.ReadAllConfig{ reader: file, read_to_end_of_stream: true }) or {
			eprintln('$app_name: $fname: Can\'t read file')
			exit(1)
		}

		new_lines << bytes.bytestr()
	} else {
		mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })
		for {
			line := br.read_line() or { break }
			if line.len > 0 {
				new_lines << line
			}
		}
	}

	return new_lines
}

// args
fn args() Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	echo := fp.bool('echo', `e`, false, 'Treat each command-line operand as an input line')
	input_range := fp.string('input-range', `i`, '', 'Act as if input came from a file containing the range of unsigned decimal integers lo…hi, one per line')
	head_count := fp.int('head-count', `n`, 0, 'Output at most count lines. By default, all input lines are output')
	output := fp.string('output', `o`, '', 'Write output to output-file instead of standard output')
	random_source := fp.string('random-source', 0, '', 'Use file as a source of random data used to determine which permutation to generate')
	repeat := fp.bool('repeat', `r`, false, 'Repeat output values')
	zero_terminated := fp.bool('zero-terminated', `z`, false, 'Delimit items with a zero byte rather than a newline')

	fnames := fp.remaining_parameters()

	return Settings{echo, input_range, head_count, output, random_source, repeat, zero_terminated, fnames}
}
