module dd

import common

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('dd (V coreutils) ${common.version}')
			exit(0)
		}
		// Every operand is of the form name=value; there are no options.
		eq := a.index('=') or {
			common.exit_with_error_message('dd', "unrecognized operand '${a}'")
		}
		name := a[..eq]
		value := a[eq + 1..]
		match name {
			'if' { s.ifile = value }
			'of' { s.ofile = value }
			'bs' {
				s.bs = parse_size(value, false)
				s.ibs = s.bs
				s.obs = s.bs
				s.ibs_set = false
				s.obs_set = false
			}
			'ibs' {
				s.ibs = parse_size(value, false)
				s.ibs_set = true
			}
			'obs' {
				s.obs = parse_size(value, false)
				s.obs_set = true
			}
			'cbs' {
				s.cbs = parse_size(value, false)
				s.cbs_set = true
			}
			'count' {
				s.count = parse_size(value, true)
				s.count_set = true
			}
			'skip' { s.skip = parse_size(value, true) }
			'iseek' { s.skip = parse_size(value, true) }
			'seek' { s.seek = parse_size(value, true) }
			'status' {
				match value {
					'none' { s.status = .none }
					'noxfer' { s.status = .noxfer }
					else {
						common.exit_with_error_message('dd', "invalid status flag: '${value}'")
					}
				}
			}
			'conv' {
				for c in value.split(',') {
					if !is_known_conv(c) {
						common.exit_with_error_message('dd', "invalid conversion: '${c}'")
					}
					s.conv << c
				}
			}
			'iflag' {
				for c in value.split(',') {
					if !is_known_iflag(c) {
						common.exit_with_error_message('dd', "invalid input flag: '${c}'")
					}
					s.iflag << c
				}
			}
			'oflag' {
				for c in value.split(',') {
					if !is_known_oflag(c) {
						common.exit_with_error_message('dd', "invalid output flag: '${c}'")
					}
					s.oflag << c
				}
			}
			else {
				common.exit_with_error_message('dd', "unrecognized operand '${name}'")
			}
		}
	}
	return s
}

fn is_known_conv(c string) bool {
	return c in ['notrunc', 'noerror', 'sync', 'fdatasync', 'fsync', 'swab', 'excl', 'nocreat',
		'sparse', 'lcase', 'ucase', 'ascii', 'ebcdic', 'ibm', 'block', 'unblock']
}

fn is_known_iflag(c string) bool {
	return c in ['count_bytes', 'skip_bytes', 'fullblock', 'direct', 'nonblock', 'noatime', 'nocache',
		'directory']
}

fn is_known_oflag(c string) bool {
	return c in ['append', 'seek_bytes', 'direct', 'nonblock', 'noatime', 'nocache', 'directory']
}

// parse_size accepts a decimal count with an optional unit suffix. GNU
// refuses a zero block size but permits a zero count, skip or seek.
fn parse_size(v string, allow_zero bool) u64 {
	n := parse_block_size(v, allow_zero)
	return n
}

fn parse_size_u64(v string) u64 {
	return parse_block_size(v, true)
}

// parse_block_size parses a bs= style operand. A bare K, M or G is a power of
// two and KB, MB, GB a power of ten, so bs=1K is 1024 while bs=1KB is 1000;
// measured against GNU 9.4. A bare letter such as "K" means one unit.
fn parse_block_size(v string, allow_zero bool) u64 {
	if v == '' {
		common.exit_with_error_message('dd', "invalid number: '${v}'")
	}
	mut digits_end := 0
	for digits_end < v.len && v[digits_end] >= `0` && v[digits_end] <= `9` {
		digits_end++
	}
	num := v[..digits_end]
	rest := v[digits_end..]
	mut n := u64(0)
	if num == '' {
		n = 1
	} else {
		for c in num.bytes() {
			if c < `0` || c > `9` {
				common.exit_with_error_message('dd', "invalid number: '${v}'")
			}
			n = n * 10 + u64(c - `0`)
		}
	}
	if n == 0 && !allow_zero {
		common.exit_with_error_message('dd', "invalid number: '${v}'")
	}
	if rest == '' {
		return n
	}
	mut mult := u64(0)
	// A bare K or M is a power of two; KB or MB is a power of ten; KiB stays
	// a power of two. So decimal only when the suffix ends in B without an
	// i before it, which is what separates KB from KiB.
	binary := !rest.ends_with('B') || rest.ends_with('iB')
	match rest.trim_right('B').trim_right('i').to_upper() {
		'B' { mult = 512 }
		'K' { mult = if binary { u64(1024) } else { u64(1000) } }
		'M' { mult = if binary { u64(1024) * 1024 } else { u64(1000) * 1000 } }
		'G' { mult = if binary { u64(1024) * 1024 * 1024 } else { u64(1000) * 1000 * 1000 } }
		'T' {
			mult = if binary {
				u64(1024) * 1024 * 1024 * 1024
			} else {
				u64(1000) * 1000 * 1000 * 1000
			}
		}
		'P' {
			mult = if binary {
				u64(1024) * 1024 * 1024 * 1024 * 1024
			} else {
				u64(1000) * 1000 * 1000 * 1000 * 1000
			}
		}
		'E' { mult = u64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 }
		'Z' { mult = u64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 }
		'Y' { mult = u64(1024) * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 * 1024 }
		'C' { mult = 1 }
		'W' { mult = 2 }
		else {
			common.exit_with_error_message('dd', "invalid number: '${v}'")
			return 0
		}
	}
	return n * mult
}

fn print_help() {
	println('Usage: dd [OPERAND]...')
	println('Copy a file, converting and formatting according to the operands.')
	println('')
	println('  bs=BYTES        read and write up to BYTES bytes at a time (default: 512)')
	println('  cbs=BYTES       convert BYTES bytes at a time')
	println('  conv=CONVS      convert the file as per the comma separated symbol list')
	println('  count=N         copy only N input blocks')
	println('  ibs=BYTES       read up to BYTES bytes at a time (default: 512)')
	println('  if=FILE         read from FILE instead of the standard input')
	println('  iflag=FLAGS     read as per the comma separated symbol list')
	println('  obs=BYTES       write BYTES bytes at a time (default: 512)')
	println('  of=FILE         write to FILE instead of the standard output')
	println('  oflag=FLAGS     write as per the comma separated symbol list')
	println('  seek=N          skip N obs-sized blocks at the start of the output')
	println('  skip=N          skip N ibs-sized blocks at the start of the input')
	println('  status=LEVEL    the LEVEL of information to print to the standard error')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
