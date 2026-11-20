module stdbuf

import common

const app_name = 'stdbuf'

// Which stream an -i, -o or -e option applies to.
pub enum Stream {
	input
	output
	error
}

// How a stream is buffered.
pub enum Mode {
	unbuffered // 0
	line       // L
	bytes      // an explicit size
}

pub struct Settings {
pub mut:
	// One mode per stream, in the order the options were given.
	modes   []StreamMode
	command []string
}

pub struct StreamMode {
pub:
	stream Stream
	mode   Mode
	size   u64
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut command := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('stdbuf (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			command = args[i + 1..].clone()
			break
		}
		if !a.starts_with('-') || a == '-' {
			// The first non-option operand starts the command.
			command = args[i..].clone()
			break
		}

		if a.starts_with('-') && a.len > 1 {
			c := a[1]
			if c != `i` && c != `o` && c != `e` {
				common.die(app_name, "invalid option -- '${c.ascii_str()}'", 125)
			}
			value := if a.len > 2 {
				a[2..]
			} else {
				if i + 1 >= args.len {
					common.die(app_name, "option requires an argument -- '${c.ascii_str()}'",
						125)
				}
				i++
				args[i]
			}
			stream := if c == `i` {
				Stream.input
			} else if c == `o` {
				Stream.output
			} else {
				Stream.error
			}
			mode, size := parse_mode(value)
			s.modes << StreamMode{
				stream: stream
				mode:   mode
				size:   size
			}
		}
	}

	s.command = command
	return s
}

// parse_mode reads an -i/-o/-e value. L means line buffered, 0 means
// unbuffered, and anything else is a byte count with an optional k/m/g
// suffix.
fn parse_mode(v string) (Mode, u64) {
	if v == '' {
		return Mode.bytes, 0
	}
	if v == 'L' {
		return Mode.line, 0
	}
	last := v[v.len - 1]
	mut mult := u64(1)
	mut digits := v
	match last {
		`k` {
			mult = 1024
			digits = v[..v.len - 1]
		}
		`K` {
			mult = 1024
			digits = v[..v.len - 1]
		}
		`m` {
			mult = 1024 * 1024
			digits = v[..v.len - 1]
		}
		`M` {
			mult = 1024 * 1024
			digits = v[..v.len - 1]
		}
		`g` {
			mult = 1024 * 1024 * 1024
			digits = v[..v.len - 1]
		}
		`G` {
			mult = 1024 * 1024 * 1024
			digits = v[..v.len - 1]
		}
		else {}
	}
	mut n := u64(0)
	for c in digits.bytes() {
		if c < `0` || c > `9` {
			common.die(app_name, "invalid mode '${v}': Value too large for defined data type",
				125)
		}
		n = n * 10 + u64(c - `0`)
	}
	if v == '0' {
		return Mode.unbuffered, 0
	}
	return Mode.bytes, n * mult
}

fn print_help() {
	println('Usage: stdbuf OPTION... COMMAND')
	println('Run COMMAND, with modified buffering operations for its standard streams.')
	println('')
	println('  -i, --input=MODE   adjust standard input stream buffering')
	println('  -o, --output=MODE  adjust standard output stream buffering')
	println('  -e, --error=MODE   adjust standard error stream buffering')
	println('      --help     display this help and exit')
	println('      --version  output version information and exit')
	println('')
	println("If MODE is 'L' the corresponding stream will be line buffered.")
	println("If MODE is '0' the corresponding stream will be unbuffered.")
	println('Otherwise MODE is a number which may be followed by a size suffix.')
}
