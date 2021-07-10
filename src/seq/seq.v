module main

import flag
import os
import math

const (
	app_name        = 'seq'
	app_version     = 'v0.0.1'
	app_description = 'print a sequence of numbers'
)

struct Settings {
	format      string
	separator   string
	equal_width bool
	first       string // can be a decimal
	increment   string
	last        string
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	seq(args())
}

//
fn seq(set Settings) {
	last := set.last.f64()
	inc := set.increment.f64()

	/// gets format string for printf
	// fstr := get_fstr(set)
	fstr := '${get_fstr(set)}'
	println(fstr)

	mut i := set.first.f64()
	for i <= last {
		C.printf(fstr.str, i)
		i += inc
	}
}

///===================================================================///
///                       Helper Functions                            ///
///===================================================================///

// returns the string used in printf, example "05.3f"
fn get_fstr(set Settings) string {
	// use value in --format as specified by user.
	if set.format != '' {
		return set.format
	}
	// else

	// number of 0s to pad  on the right, 5.0 with 6 padding => 00005.0
	mut padding := 0
	// C's pritnf type
	mut ctype := 'f'

	idec := num_of_decimals(set.increment)
	fdec := num_of_decimals(set.first)
	// number of decimal places, 9.000000 => 5 decimals
	decimals := largest(idec, fdec)

	// equalize the width by padding with zeros
	// 001,002,...100
	if set.equal_width {
		flen := set.first.split('.')[0].len
		llen := set.last.split('.')[0].len
		padding = largest(flen, llen)
	}

	return '%0${padding}.$decimals$ctype$set.separator'
}

// '9.00' => 2, 0.889 => 3
[inline]
fn num_of_decimals(s string) int {
	return if s.split('.').len > 1 { s.split('.')[1].len } else { 0 }
}

// returns largest number
[inline]
fn largest(x int, y int) int {
	return if x > y { x } else { y }
}

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
	format := fp.string('format', `f`, '', 'use printf style floating-point FORMAT')
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
			return Settings{format, separator, equal_width, '0', '1', fnames[0]}
		}
		2 {
			//  first=fnames[0], _, last=fnames[1],
			return Settings{format, separator, equal_width, fnames[0], '1', fnames[1]}
		}
		3 {
			//  first=fnames[0], increment[1], last=fnames[2],
			return Settings{format, separator, equal_width, fnames[0], fnames[1], fnames[2]}
		}
		else {
			eprintln("$app_name: extra operand '${fnames[3]}'")
			eprintln("Try '$app_name --help' for more information.")
			exit(1)
		}
	}
	// making compiler happy, should never happen
	return Settings{format, separator, equal_width, '0', '0', '0'}
}
