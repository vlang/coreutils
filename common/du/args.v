module du

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
			println('du (V coreutils) ${common.version}')
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
				'--all' {
					s.all = true
				}
				'--bytes' {
					s.mode = .bytes
				}
				'--summarize' {
					s.summary = true
				}
				'--total' {
					s.total = true
				}
				'--human-readable' {
					s.mode = .human
				}
				'--si' {
					s.mode = .si_human
				}
				'--apparent-size' {
					s.mode = .bytes
				}
				'--block-size' {
					value, next := take_value(args, i, val, has_val, name)
					i = next
					s.mode = .blocks
					s.block_size = value.int()
				}
				'--max-depth' {
					value, next := take_value(args, i, val, has_val, name)
					i = next
					s.max_depth = value.int()
				}
				else {
					common.exit_with_error_message('du', "unrecognized option '${a}'")
				}
			}
			continue
		}

		// Clusters such as -sh and -ab are ordinary usage, so short options
		// are expanded here; a value-taking option in a cluster takes the
		// rest of the same word as its value.
		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`a` {
					s.all = true
				}
				`b` {
					s.mode = .bytes
				}
				`c` {
					s.total = true
				}
				`h` {
					s.mode = .human
				}
				`H` {
					s.mode = .si_human
				}
				`k` {
					s.mode = .kibibytes
				}
				`m` {
					s.mode = .mebibytes
				}
				`g` {
					s.mode = .gibibytes
				}
				`s` {
					s.summary = true
				}
				`D`, `d` {
					rest := a[j + 1..]
					mut value := rest
					if rest == '' {
						if i + 1 >= args.len {
							common.exit_with_error_message('du', "option requires an argument -- '${c.ascii_str()}'")
						}
						i++
						value = args[i]
					}
					s.max_depth = value.int()
					j = a.len
					continue
				}
				`B` {
					rest := a[j + 1..]
					mut value := rest
					if rest == '' {
						if i + 1 >= args.len {
							common.exit_with_error_message('du', "option requires an argument -- '${c.ascii_str()}'")
						}
						i++
						value = args[i]
					}
					s.mode = .blocks
					s.block_size = value.int()
					j = a.len
					continue
				}
				else {
					common.exit_with_error_message('du', "invalid option -- '${c.ascii_str()}'")
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
		common.exit_with_error_message('du', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: du [OPTION]... [FILE]...')
	println('Summarize device usage of the set of FILEs, recursively for directories.')
	println('')
	println('  -a, --all             write counts for all files, not just directories')
	println('      --apparent-size   print apparent sizes rather than device usage')
	println('  -B, --block-size=SIZE scale sizes by SIZE before printing them')
	println('  -b, --bytes           equivalent to --apparent-size --block-size=1')
	println('  -c, --total           produce a grand total')
	println('  -d, --max-depth=N     print the total for a directory only if it is')
	println('                          N or fewer levels below the command line argument')
	println('      --files0-from=F   summarize device usage of the NUL-terminated file')
	println('      --si              like -h, but use powers of 1000 not 1024')
	println('  -s, --summarize       display only a total for each argument')
	println('  -h, --human-readable  print sizes in human readable format')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
