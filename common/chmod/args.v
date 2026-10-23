module chmod

import common

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}
	mut mode_set := false

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
			println('chmod (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '-' {
			operands << a
			continue
		}
		if !a.starts_with('-') {
			// The mode is the first non-option operand.
			if !mode_set {
				s.mode = a
				mode_set = true
			} else {
				operands << a
			}
			continue
		}
		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--recursive' {
					s.recursive = true
				}
				'--verbose' {
					s.verbose = true
				}
				'--changes' {
					s.changes = true
				}
				'--reference' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.reference = v
				}
				'--silent', '--quiet' {}
				else {
					common.exit_with_error_message('chmod', "unrecognized option '${a}'")
				}
			}
			continue
		}

		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`R` {
					s.recursive = true
				}
				`v` {
					s.verbose = true
				}
				`c` {
					s.changes = true
				}
				`f` {}
				`-` {
					j++
					continue
				}
				else {
					common.exit_with_error_message('chmod', "invalid option -- '${c.ascii_str()}'")
				}
			}
			j++
		}
	}

	if !mode_set && s.reference == '' {
		common.exit_with_error_message('chmod', 'missing operand')
	}
	if operands.len == 0 {
		if mode_set {
			common.exit_with_error_message('chmod', 'missing operand after ‘${s.mode}’')
		} else {
			common.exit_with_error_message('chmod', 'missing operand')
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
		common.exit_with_error_message('chmod', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: chmod [OPTION]... MODE[,MODE]... FILE...')
	println('  or:  chmod [OPTION]... OCTAL-MODE FILE...')
	println('Change the mode of each FILE to MODE.')
	println('')
	println('  -c, --changes   like verbose but report only when a change is made')
	println('  -f, --silent, --quiet   suppress most error messages')
	println('  -v, --verbose     output a diagnostic for every file processed')
	println('      --reference=FILE  use the mode of FILE instead of MODE values')
	println('  -R, --recursive   change files and directories recursively')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
