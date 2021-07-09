module main

import flag
import os

const (
	app_name        = 'seq'
	app_version     = 'v0.0.1'
	app_description = 'print a sequence of numbers'
)

struct Settings {
	format      string
	separator   string
	equal_width bool
	first       f64 // can be a decimal
	increment   f64
	last        f64
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	seq(args())
}

fn seq(s Settings) {
	sep := s.separator.bytes()
	last := s.last
	inc := s.increment

	mut i := s.first
	mut stdout := os.stdout()
	for i <= last {
		stdout.write(i.str().bytes()) or {}
		stdout.write(sep) or {}
		i += inc
	}
}

///===================================================================///
///                       Helper Functions                            ///
///===================================================================///

///===================================================================///
///                                Args                               ///
///===================================================================///

fn args() Settings {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(app_version)
	fp.description(app_description)
	fp.skip_executable()

	// need to change this
	format := fp.string('format', `f`, '%i', 'use printf style floating-point FORMAT')
	separator := fp.string('separator', `s`, '\n', 'use STRING to separate numbers (default: \n)')
	equal_width := fp.bool('equal-width', `w`, false, 'equalize width by padding with leading zeroes')

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	// extra arguments -a -b -c arg1 arg2 arg3
	// arg1..3 will be taken
	// flags used that are not specified will panic
	fnames := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	if help {
		println(fp.usage())
		exit(0)
	}
	if version {
		println('$app_name $app_version')
		exit(0)
	}

	match fnames.len {
		0 {
			eprintln('$app_name: missinge operand')
			eprintln("Try '$app_name --help' for more information.")
			exit(1)
		}
		1 {
			// _, _, last=fnames[0]
			return Settings{format, separator, equal_width, 0, 1, fnames[0].f64()}
		}
		2 {
			//  first=fnames[0], _, last=fnames[1],
			return Settings{format, separator, equal_width, fnames[0].f64(), 1, fnames[1].f64()}
		}
		3 {
			//  first=fnames[0], increment[1], last=fnames[2],
			return Settings{format, separator, equal_width, fnames[0].f64(), fnames[1].f64(), fnames[2].f64()}
		}
		else {
			eprintln("$app_name: extra operand '${fnames[3]}'")
			eprintln("Try '$app_name --help' for more information.")
			exit(1)
		}
	}
	// making compiler happy, should never happen
	return Settings{format, separator, equal_width, 0, 0, 0}
}
