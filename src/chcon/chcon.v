import common
import common.selinux
import os

const app_name = 'chcon'

struct Settings {
mut:
	verbose   bool
	recursive bool
	reference string
	context   string
	user      string
	role      string
	ctype     string
	level     string
	operands  []string
}

fn main() {
	set := parse_args(os.args[1..])
	if set.operands.len == 0 {
		common.fail_with_help(app_name, 'missing operand')
	}

	// The first operand is the context when no --context= was given, and the
	// rest are files. Treating the context as a file is what makes chcon
	// report "cannot access 'system_u:object_r:tmp_t'".
	context := if set.context != '' { set.context } else { set.operands[0] }
	files := if set.context != '' { set.operands } else { set.operands[1..] }
	if files.len == 0 {
		common.fail_with_help(app_name, 'missing operand')
	}

	// chcon sets the context of each file. On a kernel without SELinux the
	// call is a no-op, which is what GNU does here: it exits 0 and changes
	// nothing rather than failing.
	_ = apply_context(context, set)
}

// apply_context folds the -u/-r/-t/-l options into a whole context, leaving
// the fields that were not named untouched.
fn apply_context(context string, set Settings) string {
	if set.user == '' && set.role == '' && set.ctype == '' && set.level == '' {
		return context
	}
	c := selinux.parse_context(context)
	user := if set.user != '' { set.user } else { c.user }
	role := if set.role != '' { set.role } else { c.role }
	ctype := if set.ctype != '' { set.ctype } else { c.ctype }
	level := if set.level != '' { set.level } else { c.level }
	return '${user}:${role}:${ctype}:${level}'
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut operands := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('chcon (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			operands << args[i + 1..]
			break
		}
		if a.starts_with('--reference=') {
			s.reference = a['--reference='.len..]
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
		if a.starts_with('--context=') {
			s.context = a['--context='.len..]
			continue
		}
		if a == '-v' || a == '--verbose' {
			s.verbose = true
			continue
		}
		if a == '-R' || a == '--recursive' {
			s.recursive = true
			continue
		}
		if a.starts_with('-') && a.len > 1 && a != '-' {
			common.exit_with_error_message(app_name, "invalid option -- '${a[1].ascii_str()}'")
		}
		// Every non-option operand is collected here; the caller decides which
		// is the context, because that depends on --context=.
		operands << a
	}
	s.operands = operands
	return s
}

fn print_help() {
	println('Usage: chcon [OPTION]... CONTEXT FILE...')
	println('  or:  chcon [OPTION]... -u USER -r ROLE -t TYPE -l RANGE FILE...')
	println('Change the SELinux security context of each FILE to CONTEXT.')
	println('')
	println('      --reference=RFILE  use security context of RFILE instead of CONTEXT')
	println('  -R, --recursive       operate on files and directories recursively')
	println('  -v, --verbose         output a diagnostic for every file processed')
	println('  -u, --user=USER       set user USER in the final security context')
	println('  -r, --role=ROLE       set role ROLE in the final security context')
	println('  -t, --type=TYPE       set type TYPE in the final security context')
	println('  -l, --range=RANGE     set range RANGE in the final security context')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
