module realpath

import common

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--' {
			operands << args[i + 1..]
			break
		}
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('realpath (V coreutils) ${common.version}')
			exit(0)
		}
		if !a.starts_with('-') || a == '-' {
			operands << a
			continue
		}

		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--canonicalize-existing' {
					s.must_exist = true
				}
				'--canonicalize-missing' {
					s.allow_missing = true
				}
				'--no-symlinks' {
					s.no_symlinks = true
				}
				'--zero' {
					s.zero_terminated = true
				}
				'--quiet' {
					s.quiet = true
				}
				'--relative-to' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.relative_to = v
				}
				'--relative-base' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.relative_base = v
				}
				'--logical' {
					s.no_symlinks = true
				}
				'--physical' {}
				else {
					common.exit_with_error_message('realpath', "unrecognized option '${a}'")
				}
			}
			continue
		}

		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`e` {
					s.must_exist = true
				}
				`m` {
					s.allow_missing = true
				}
				`s` {
					s.no_symlinks = true
				}
				`z` {
					s.zero_terminated = true
				}
				`q` {
					s.quiet = true
				}
				`L` {
					s.no_symlinks = true
				}
				`P` {}
				`-` {
					j++
					continue
				}
				else {
					common.exit_with_error_message('realpath', "invalid option -- '${c.ascii_str()}'")
				}
			}
			j++
		}
	}

	s.operands = operands
	return s
}

fn take_value(args []string, i int, inline_val string, has_val bool, name string) (string, int) {
	if has_val {
		return inline_val, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('realpath', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: realpath [OPTION]... FILE...')
	println('Print the resolved absolute file name; all but the last component must exist')
	println('')
	println('  -e, --canonicalize-existing  all components of the path must exist')
	println('  -m, --canonicalize-missing   no path components need exist')
	println('  -L, --logical                resolve .. components before symlinks')
	println('  -P, --physical               resolve symlinks as encountered (default)')
	println('  -q, --quiet                  suppress most error messages')
	println('      --relative-to=DIR        print the resolved path relative to DIR')
	println('      --relative-base=DIR      print absolute paths unless paths below DIR')
	println('  -s, --strip, --no-symlinks   do not expand symlinks')
	println('  -z, --zero                   end each output line with NUL, not newline')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
