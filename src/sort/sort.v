import os

// A line of input, and where it came from, which the check mode needs in order to
// report a disorder.
struct InputLine {
	text string
	file string
	// number counts from one, so that the first line is line 1.
	number int
	// order is where the line came in. V's sort is not stable, and -s and -u both
	// depend on lines that compare equal keeping the order they arrived in, so the
	// position has to be part of the comparison.
	order int
}

fn main() {
	options, keys := get_options()

	// -c looks for one disorder and reports where it is, so there is only one input.
	// GNU quotes the extra name and gives no advice about --help.
	if options.check != .none && options.files.len > 1 {
		error_only("extra operand '${options.files[1]}' not allowed with -c")
	}

	if options.merge {
		// -m promises each input is sorted already, so the streams are merged as
		// they stand rather than sorted together.
		emit(merge_input(read_each_input(options), options, keys), options)
		return
	}

	lines := read_all_input(options)

	if options.check != .none {
		check_input(lines, options, keys)
		return
	}

	mut sorted := sort_lines(lines, options, keys)
	sorted = unique_lines(sorted, options, keys)
	emit(sorted, options)
}

// emit writes the result to -o's file, or to standard output when no file was
// given.
fn emit(lines []InputLine, options Options) {
	delim := line_delimiter(options)
	if options.output.len > 0 {
		mut file := os.create(options.output) or {
			// GNU says "open failed" here, not "cannot write": measured on 9.4, where
			// "sort -o nodir/out.txt" answers
			// "sort: open failed: nodir/out.txt: No such file or directory".
			eprintln('${app_name}: open failed: ${options.output}: ${os.error_posix().msg()}')
			exit(2)
		}
		for line in lines {
			file.write_string(line.text + delim) or {
				exit_error('write failed')
			}
		}
		file.close()
		return
	}
	mut out := os.stdout()
	for line in lines {
		out.write_string(line.text + delim) or {
			exit_error('write failed')
		}
	}
	out.flush()
}

fn line_delimiter(options Options) string {
	return if options.zero_terminated { '\x00' } else { '\n' }
}

@[noreturn]
fn exit_error(message string) {
	eprintln('${app_name}: ${message}')
	exit(2)
}

@[noreturn]
fn read_error(file string) {
	eprintln('${app_name}: cannot read: ${file}: ${os.error_posix().msg()}')
	exit(2)
}
