module main

import common
import os
import strconv

const (
	app_name        = 'seq'
	app_description = 'print a sequence of numbers'
)

struct Settings {
	format      string
	separator   string
	equal_width bool
	first       string
	increment   string
	last        string
}

///===================================================================///
///                       Main Logic                                  ///
///===================================================================///

fn main() {
	settings := args() ?

	// sanitize settings
	check_settings(settings) or {
		eprintln(err)
		eprintln("Try '$app_name --help' for more information.")
		exit(1)
	}

	seq(settings)
}

fn seq(set Settings) {
	last := set.last.f64()
	inc := set.increment.f64()

	/// gets format string for printf
	fstr := get_fstr(set)

	mut i := set.first.f64()
	for i < last {
		i += inc
		print(strconv.v_sprintf(fstr, i))
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

		// decimals are counted in padding
		// 0.999 padded to 6 => 00.999
		if decimals > 0 {
			padding += decimals + 1 // +1 since '.' is counted too
		}
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

[inline]
fn check_settings(set Settings) ? {
	if set.increment.f64() == 0 {
		return error("$app_name: invalid zero increment value '0'")
	}
}

///===================================================================///
///                                Args                               ///
///===================================================================///

fn args() ?Settings {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	// need to change this
	format := fp.string('format', `f`, '', 'use printf style floating-point FORMAT')
	separator := fp.string('separator', `s`, '\n', 'use STRING to separate numbers (default: \n)')
	equal_width := fp.bool('equal-width', `w`, false, 'equalize width by padding with leading zeroes')

	// extra arguments -a -b -c arg1 arg2 arg3
	// arg1..3 will be taken
	// flags used that are not specified will panic
	fnames := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}

	match fnames.len {
		0 {
			eprintln('$app_name: missing operand')
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
	return error('invalid parameters')
}
