import common
import os

const app_name = 'chown'

struct Settings {
mut:
	recursive bool
	verbose   bool
	changes   bool // -c
	from      string
	spec      string
	operands  []string
}

fn main() {
	set := parse_args(os.args[1..])
	if set.operands.len == 0 {
		if set.spec != '' {
			// GNU names the operand it was expecting after.
			common.fail_with_help(app_name, 'missing operand after ‘${set.spec}’')
		}
		common.fail_with_help(app_name, 'missing operand')
	}

	owner, group := parse_spec(set.spec) or {
		// GNU uses curly quotes and does not print the "Try --help" line for
		// an unresolvable name.
		common.die(app_name, 'invalid user: ‘${set.spec}’', 1)
	}

	mut failed := false
	for operand in set.operands {
		if !os.exists(operand) {
			common.exit_with_error_message(app_name, "cannot access '${operand}': No such file or directory")
		}
		res := common.change_owner(operand, owner, group)
		if res != 0 {
			eprintln('${app_name}: changing ownership of "${operand}": Operation not permitted')
			failed = true
			continue
		}
		if set.changes || set.verbose {
			eprintln("ownership of '${operand}' retained as ${common.user_name(owner)}")
		}
	}
	if failed {
		exit(1)
	}
}

// parse_spec splits "user:group" into the ids chown needs. A value of leave_alone
// in either field means that half was not named.
const leave_alone = common.leave_alone

fn parse_spec(spec string) ?(u32, u32) {
	mut user_part := spec
	mut group_part := ''
	if spec.contains(':') {
		parts := spec.split(':')
		user_part = parts[0]
		group_part = parts[1]
	}

	mut owner := leave_alone
	mut group := leave_alone
	if user_part != '' {
		owner = common.user_id(user_part)?
	}
	if group_part != '' {
		group = common.group_id(group_part)?
	}
	return owner, group
}

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
			println('chown (V coreutils) ${common.version}')
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
			s.from = a['--reference='.len..]
			continue
		}
		if a.starts_with('--from=') {
			s.from = a['--from='.len..]
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
	println('Usage: chown [OPTION]... [OWNER][:[GROUP]] FILE...')
	println('  or:  chown [OPTION]... --reference=RFILE FILE...')
	println('')
	println('  -c, --changes          like verbose but report only when a change is made')
	println('  -f, --silent, --quiet  suppress most error messages')
	println('      --dereference      affect the referent of each symbolic link')
	println('  -h, --no-dereference   affect symbolic links instead of referenced files')
	println('      --from=CURRENT_OWNER:CURRENT_GROUP')
	println('      --reference=RFILE  use RFILE owner and group')
	println('  -R, --recursive        operate on files and directories recursively')
	println('  -v, --verbose          output a diagnostic for every file processed')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
