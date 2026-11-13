import common
import os

const app_name = 'runcon'

struct Settings {
mut:
	context string
	user    string
	role    string
	ctype   string
	level   string
	command []string
}

fn main() {
	set := parse_args(os.args[1..])
	if set.command.len == 0 {
		common.die(app_name, 'missing operand', 125)
	}

	// runcon changes the context of a child process rather than of a file. On
	// a kernel without SELinux there is nothing to change, so GNU reports that
	// and exits 125 rather than running the command.
	common.die(app_name, 'runcon may be used only on a SELinux kernel', 125)
}

// context_for folds the -u/-r/-t/-l options into a whole context, leaving the
// fields that were not named untouched.
fn context_for(set Settings) string {
	if set.context != '' {
		return set.context
	}
	return '${set.user}:${set.role}:${set.ctype}:${set.level}'
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut rest := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('runcon (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			rest << args[i + 1..]
			break
		}
		if a.starts_with('--context=') {
			s.context = a['--context='.len..]
			continue
		}
		if a.starts_with('--user=') {
			s.user = a['--user='.len..]
			continue
		}
		if a.starts_with('--role=') {
			s.role = a['--role='.len..]
			continue
		}
		if a.starts_with('--type=') {
			s.ctype = a['--type='.len..]
			continue
		}
		if a.starts_with('--range=') {
			s.level = a['--range='.len..]
			continue
		}
		if a.starts_with('-') && a.len > 1 && a != '-' {
			common.exit_with_error_message(app_name, "invalid option -- '${a[1].ascii_str()}'")
		}
		rest << a
	}
	s.command = rest
	return s
}

fn print_help() {
	println('Usage: runcon CONTEXT COMMAND [args...]')
	println('  or:  runcon [ -c ] [-u USER] [-r ROLE] [-t TYPE] [-l RANGE] COMMAND [args...]')
	println('Run a program in a different SELinux security context.')
	println('')
	println('  -c, --compute       compute process transition context before modifying')
	println('  -t, --type=TYPE     type (for same role as parent)')
	println('  -u, --user=USER     user identity')
	println('  -r, --role=ROLE     role')
	println('  -l, --range=RANGE   levelrange')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
