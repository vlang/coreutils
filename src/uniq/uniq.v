module main

import io
import math
import os

// POSIX Spec: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/uniq.html
const app_name = 'uniq'
const app_description = 'report or omit repeated lines'

struct Buffer {
mut:
	seen  string
	count int
}

@[noreturn]
fn fail(message string) {
	eprintln('${app_name}: ${message}')
	exit(1)
}

fn output_line(s Buffer, settings Settings, mut outfile os.File) !bool {
	if s.count > 0 {
		if (!settings.unique && !settings.repeated)
			|| (settings.unique && s.count == 1)
			|| (settings.repeated && s.count > 1) {
			if settings.count {
				outfile.write('${s.count:7} '.bytes())!
			}
			outfile.write('${s.seen}'.bytes())!
			outfile.write(rune(settings.line_delimiter).bytes())!
		}
	}
	return true
}

fn get_start_of_field(source string, target_field int) int {
	mut field := 0
	mut interstitial := true
	for i in 0 .. source.len {
		if source[i].is_space() {
			interstitial = true
		} else {
			if interstitial {
				field += 1
				interstitial = false
				// If we skip n fields, we want the start of field n+1
				if field == target_field {
					return i
				}
			}
		}
	}
	return source.len
}

fn compare(source string, target string, settings Settings) bool {
	mut s1 := source
	mut s2 := target

	if settings.skip_fields > -1 {
		s1 = s1[get_start_of_field(s1, settings.skip_fields + 1)..]
		s2 = s2[get_start_of_field(s2, settings.skip_fields + 1)..]
	}

	if settings.skip_chars > -1 {
		s1 = source[math.min(s1.len, settings.skip_chars)..]
		s2 = target[math.min(s2.len, settings.skip_chars)..]
	}

	if settings.check_chars > -1 {
		s1 = source[0..math.min(s1.len, settings.check_chars)]
		s2 = target[0..math.min(s2.len, settings.check_chars)]
	}

	if settings.case_insensitive {
		return s1.to_lower() == s2.to_lower()
	} else {
		return s1 == s2
	}
}

fn uniq(settings Settings) {
	mut file := os.File{}
	mut outfile := os.File{}
	if settings.input_file == '-' {
		file = os.stdin()
	} else {
		file = os.open(settings.input_file) or {
			fail('${settings.input_file}: No such file or directory')
		}
	}
	defer {
		file.close()
	}

	if settings.output_file == '-' {
		outfile = os.stdout()
	} else {
		outfile = os.create(settings.output_file) or {
			fail('${settings.output_file}: No such file or directory')
		}
	}
	defer {
		outfile.close()
	}

	mut br := io.new_buffered_reader(io.BufferedReaderConfig{ reader: file })
	defer {
		br.free()
	}

	mut s := Buffer{
		seen: ''
		count: 0
	}
	for {
		line := br.read_line(delim: settings.line_delimiter) or { break }
		if !compare(line, s.seen, settings) {
			output_line(s, settings, mut &outfile) or { panic(err) }
			s.seen = line
			s.count = 1
		} else {
			s.count += 1
		}
	}
	output_line(s, settings, mut &outfile) or { panic(err) }
}

fn main() {
	uniq(args())
}
