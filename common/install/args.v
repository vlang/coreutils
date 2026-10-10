module install

import common
import os

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
			println('install (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '-' || !a.starts_with('-') {
			operands << a
			continue
		}

		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--mode' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					s.mode = v
					s.mode_given = true
				}
				'--directory' {
					s.dir_flag = true
				}
				'--target-directory' {
					v, next := take_value(args, i, val, has_val, name)
					i = next
					// -t DIRECTORY: the directory is the destination and
					// every operand is a source.
					s.target = v
					s.target_dir = true
				}
				'--no-target-directory' {}
				'--preserve-timestamps' {
					s.preserve = true
				}
				'--strip' {
					s.strip = true
				}
				'--backup' {
					s.backup = true
				}
				'--compare' {
					s.compare = true
				}
				'--verbose' {
					s.verbose = true
				}
				'--group' {
					s.group = true
				}
				'--owner' {
					s.owner = true
				}
				else {
					common.exit_with_error_message('install', "unrecognized option '${a}'")
				}
			}
			continue
		}

		mut j := 1
		for j < a.len {
			c := a[j]
			match c {
				`D` {
					s.dir_flag = true
				}
				`d` {
					s.dir_flag = true
				}
				`C` {
					s.no_clobber = true
				}
				`c` {}
				`p` {
					s.preserve = true
				}
				`s` {
					s.strip = true
				}
				`b` {
					s.backup = true
				}
				`v` {
					s.verbose = true
				}
				`g` {
					s.group = true
				}
				`o` {
					s.owner = true
				}
				`m` {
					v, next := take_short(args, i, a, j)
					i = next
					s.mode = v
					s.mode_given = true
					j = a.len
					continue
				}
				`t` {
					v, next := take_short(args, i, a, j)
					i = next
					s.target = v
					s.target_dir = true
					j = a.len
					continue
				}
				`-` {
					j++
					continue
				}
				else {
					common.exit_with_error_message('install', "invalid option -- '${c.ascii_str()}'")
				}
			}
			j++
		}
	}

	s.operands = operands
	return s
}

fn take_short(args []string, i int, a string, j int) (string, int) {
	rest := a[j + 1..]
	if rest != '' {
		return rest, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('install', "option requires an argument -- '${a[j].ascii_str()}'")
	}
	return args[i + 1], i + 1
}

fn take_value(args []string, i int, inline_val string, has_val bool, name string) (string, int) {
	if has_val {
		return inline_val, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('install', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: install [OPTION]... [-T] SOURCE DEST')
	println('  or:  install [OPTION]... SOURCE... DIRECTORY')
	println('  or:  install [OPTION]... -t DIRECTORY SOURCE...')
	println('  or:  install [OPTION]... -d DIRECTORY...')
	println('')
	println('  -b, --backup        make a backup of each existing destination file')
	println('  -C                  compare each pair of source and destination files')
	println('  -d, --directory     treat all arguments as directory names')
	println('  -D                  create all leading components of DEST')
	println('  -g, --group=GROUP   set group ownership')
	println('  -m, --mode=MODE     set permission mode (as in chmod)')
	println('  -o, --owner=OWNER   set ownership')
	println('  -p, --preserve-timestamps  apply access/modification times')
	println('  -s, --strip         strip symbol tables')
	println('  -t, --target-directory=DIRECTORY  copy all SOURCE arguments into DIRECTORY')
	println('  -T, --no-target-directory  treat DEST as a normal file')
	println('  -v, --verbose       print the name of each directory as it is created')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
