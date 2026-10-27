import common
import os

// chgrp is chown with only the group half, so it reuses the same group lookup.
const app_name = 'chgrp'

struct Settings {
mut:
	recursive bool
	verbose   bool
	changes   bool
	reference string
	spec      string
	operands  []string
}

fn main() {
	set := parse_args(os.args[1..])
	if set.operands.len == 0 {
		if set.spec != '' {
			common.fail_with_help(app_name, 'missing operand after ‘${set.spec}’')
		}
		common.fail_with_help(app_name, 'missing operand')
	}

	group := common.group_id(set.spec) or {
		common.die(app_name, 'invalid group: ‘${set.spec}’', 1)
	}

	mut failed := false
	for operand in set.operands {
		if !os.exists(operand) {
			common.exit_with_error_message(app_name, "cannot access '${operand}': No such file or directory")
		}
		res := common.change_owner(operand, common.leave_alone, group)
		if res != 0 {
			eprintln('${app_name}: changing group of "${operand}": Operation not permitted')
			failed = true
			continue
		}
		if set.changes || set.verbose {
			eprintln("group of '${operand}' retained as ${common.group_name(group)}")
		}
	}
	if failed {
		exit(1)
	}
}

const leave_alone = common.leave_alone

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut rest := []string{}
	mut have_spec := false

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('chgrp (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			rest << args[i + 1..]
			break
		}
		if a == '--recursive' || a == '-R' {
			s.recursive = true
			continue
		}
		if a == '--verbose' || a == '-v' {
			s.verbose = true
			continue
		}
		if a == '--changes' || a == '-c' {
			s.changes = true
			continue
		}
		if a.starts_with('--reference=') {
			s.reference = a['--reference='.len..]
			continue
		}
		if a.starts_with('-') && a.len > 1 && a != '-' {
			common.exit_with_error_message(app_name, "invalid option -- '${a[1].ascii_str()}'")
		}
		if !have_spec {
			s.spec = a
			have_spec = true
		} else {
			rest << a
		}
	}
	s.operands = rest
	return s
}

fn print_help() {
	println('Usage: chgrp [OPTION]... GROUP FILE...')
	println('  or:  chgrp [OPTION]... --reference=RFILE FILE...')
	println('')
	println('  -c, --changes          like verbose but report only when a change is made')
	println('  -f, --silent, --quiet  suppress most error messages')
	println('      --reference=RFILE  use the group of RFILE rather than GROUP')
	println('  -R, --recursive        operate on files and directories recursively')
	println('  -v, --verbose          output a diagnostic for every file processed')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
