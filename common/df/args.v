module df

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
			println('df (V coreutils) ${common.version}')
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
				'--human-readable' {
					s.mode = .human
				}
				'--si' {
					s.mode = .si_human
				}
				'--inodes' {
					s.inodes = true
					s.mode = .inodes
				}
				'--print-type' {
					s.show_type = true
				}
				'--total' {
					s.total = true
				}
				'--local' {
					s.local = true
				}
				'--no-sync' {}
				'--sync' {}
				'--block-size' {
					value, next := take_value(args, i, val, has_val, name)
					i = next
					s.mode = .blocks
					s.block_size = parse_block_size(value) or {
						common.exit_with_error_message('df', '--invalid argument ${value} for option -- block-size')
					}
				}
				'--type' {
					value, next := take_value(args, i, val, has_val, name)
					i = next
					s.include_types << value.split(',')
				}
				'--exclude-type' {
					value, next := take_value(args, i, val, has_val, name)
					i = next
					s.exclude_types << value.split(',')
				}
				else {
					common.exit_with_error_message('df', "unrecognized option '${a}'")
				}
			}
			continue
		}

		// Short options. Clusters are expanded here because a cluster such as
		// -hT is common usage, and a value-taking option inside a cluster
		// takes the rest of the same word as its value.
		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`a` {
					s.all = true
				}
				`h` {
					s.mode = .human
				}
				`H` {
					s.mode = .si_human
				}
				`i` {
					s.inodes = true
					s.mode = .inodes
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
				`T` {
					s.show_type = true
				}
				`P` {
					s.mode = .blocks
					s.block_size = 512
				}
				`l` {
					s.local = true
				}
				`B`, `t`, `x` {
					rest := a[j + 1..]
					mut value := rest
					if rest == '' {
						if i + 1 >= args.len {
							common.exit_with_error_message('df', "option requires an argument -- '${c.ascii_str()}'")
						}
						i++
						value = args[i]
					}
					if c == `B` {
						s.mode = .blocks
						s.block_size = parse_block_size(value) or {
							common.exit_with_error_message('df', '--invalid argument ${value} for option -- block-size')
						}
					} else if c == `t` {
						s.include_types << value.split(',')
					} else {
						s.exclude_types << value.split(',')
					}
					j = a.len
					continue
				}
				else {
					common.exit_with_error_message('df', "invalid option -- '${c.ascii_str()}'")
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
		common.exit_with_error_message('df', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

// parse_block_size accepts the plain decimal form of --block-size. The
// suffixed forms (K, M, G, kB, ...) are accepted by GNU but are not
// implemented.
pub fn parse_block_size(s string) ?int {
	if s == '' {
		return none
	}
	for c in s {
		if c < `0` || c > `9` {
			return none
		}
	}
	return s.int()
}

fn print_help() {
	println('Usage: df [OPTION]... [FILE]...')
	println('Show information about the file system on which each FILE resides,')
	println('or all file systems by default.')
	println('')
	println('  -a, --all             include pseudo, duplicate, inaccessible file systems')
	println('  -B, --block-size=SIZE  scale sizes by SIZE before printing them')
	println('  -h, --human-readable  print sizes in powers of 1024 (e.g., 1023M)')
	println('  -H, --si              print sizes in powers of 1000 (e.g., 1.1G)')
	println('  -i, --inodes          list inode information instead of block usage')
	println('  -k                    like --block-size=1K')
	println('  -l, --local           limit listing to local file systems')
	println('  -P, --portability     use the POSIX output format')
	println('      --sync            invoke sync before getting usage information')
	println('  -T, --print-type      print file system type')
	println('  -t, --type=TYPE       limit listing to file systems of type TYPE')
	println('  -x, --exclude-type=TYPE   limit listing to file systems not of type TYPE')
	println('      --total           produce a grand total')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
