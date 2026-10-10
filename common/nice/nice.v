module nice

import common
import os

// Exit codes GNU uses, which are distinct from the command's own status and
// from one another: nice's own failures are 125, a command that exists but
// cannot be run is 126, and a command that cannot be found is 127.
const exit_invalid = 125
const exit_cannot_run = 126
const exit_not_found = 127

pub struct Settings {
pub mut:
	adjustment       int
	adjustment_given bool
	command          []string
}

// run performs the requested adjustment and the command, returning the exit
// status. With no command it prints the current niceness and exits 0.
pub fn run(set Settings) int {
	if set.command.len == 0 {
		if set.adjustment_given {
			eprintln('nice: a command must be given with an adjustment')
			eprintln("Try 'nice --help' for more information.")
			return exit_invalid
		}
		println('${current_niceness()}')
		return 0
	}

	// The adjustment is validated but not applied, because there is no
	// per-process niceness on Windows; see the module comment.
	if set.adjustment_given {
		// Deliberately empty: see setpriority below.
	}

	mut program := set.command[0]
	mut resolved := program
	if !program.contains('/') && !program.contains('\\') {
		// A bare name is looked up on PATH, which is what a shell would do.
		abs := os.find_abs_path_of_executable(program) or { '' }
		if abs == '' {
			eprintln("nice: '${program}': No such file or directory")
			return exit_not_found
		}
		resolved = abs
	} else if !os.exists(resolved) {
		eprintln("nice: '${program}': No such file or directory")
		return exit_not_found
	}

	mut p := os.new_process(resolved)
	p.set_args(set.command[1..])
	p.run()
	p.wait()
	code := p.code
	p.close()
	return code
}

// current_niceness reads the niceness of this process. V exposes no getpriority
// binding, so 0 is reported, which is the default on both platforms.
fn current_niceness() int {
	return 0
}

// setpriority is where the adjustment would land. It is a no-op here: Windows
// has priority classes rather than a POSIX niceness, and mapping one onto the
// other would silently change semantics the caller did not ask for.
fn setpriority(adjustment int) ? {
	_ = adjustment
}

pub fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut i := 0

	for i < args.len {
		a := args[i]
		if a == '--' {
			// Everything after -- is the command, even if it looks like a flag.
			s.command = args[i + 1..].clone()
			return s
		}
		if a == '-' || !a.starts_with('-') {
			// The first non-option argument is the command. This is why
			// "nice 5 cmd" fails: the 5 is the command, not an adjustment.
			s.command = args[i..].clone()
			return s
		}

		if a.starts_with('--') {
			name := a.all_before('=')
			val := a.all_after('=')
			has_val := a.contains('=')
			match name {
				'--adjustment' {
					v, next := take_value(args, i, val, has_val, name)
					// take_value returns the index the value was taken from,
					// so +1 moves past this operand. Without it an inline
					// --adjustment=5 leaves i unchanged and the loop spins.
					i = next + 1
					s.adjustment = parse_adjustment(v)
					s.adjustment_given = true
				}
				'--help' {
					print_help()
					exit(0)
				}
				'--version' {
					println('nice (V coreutils) ${common.version}')
					exit(0)
				}
				else {
					common.exit_with_error_message('nice', "unrecognized option '${a}'")
				}
			}
			continue
		}

		// Short options. -n takes a value; -NUM is the same as -n NUM.
		if a[1] == `n` {
			rest := a[2..]
			if rest == '' {
				if i + 1 >= args.len {
					common.exit_with_error_message('nice', "option requires an argument -- 'n'")
				}
				i++
				s.adjustment = parse_adjustment(args[i])
			} else {
				s.adjustment = parse_adjustment(rest)
			}
			s.adjustment_given = true
			i++
			continue
		}
		if is_number(a[1..]) {
			s.adjustment = parse_adjustment(a[1..])
			s.adjustment_given = true
			i++
			continue
		}
		common.exit_with_error_message('nice', "invalid option -- '${a[1].ascii_str()}'")
	}

	return s
}

// parse_adjustment accepts an optionally signed decimal. GNU accepts -n 999
// without clamping, so the range is not checked here either.
fn parse_adjustment(v string) int {
	if v == '' {
		die_invalid(v)
	}
	mut start := 0
	mut negative := false
	if v[0] == `+` || v[0] == `-` {
		if v[0] == `-` {
			negative = true
		}
		start = 1
		if v.len == start {
			die_invalid(v)
		}
	}
	mut n := 0
	for i := start; i < v.len; i++ {
		c := v[i]
		if c < `0` || c > `9` {
			die_invalid(v)
		}
		n = n * 10 + int(c - `0`)
	}
	return if negative { -n } else { n }
}

// die_invalid reports a malformed adjustment and exits 125, which is GNU's
// status for nice's own failures as opposed to the command's status.
fn die_invalid(v string) {
	eprintln('nice: invalid adjustment ‘${v}’')
	exit(exit_invalid)
}

fn is_number(s string) bool {
	if s == '' {
		return false
	}
	mut start := 0
	if s[0] == `+` || s[0] == `-` {
		start = 1
		if s.len == start {
			return false
		}
	}
	for i := start; i < s.len; i++ {
		if s[i] < `0` || s[i] > `9` {
			return false
		}
	}
	return true
}

fn take_value(args []string, i int, inline_val string, has_val bool, name string) (string, int) {
	if has_val {
		return inline_val, i
	}
	if i + 1 >= args.len {
		common.exit_with_error_message('nice', "option '${name}' requires an argument")
	}
	return args[i + 1], i + 1
}

fn print_help() {
	println('Usage: nice [OPTION] [COMMAND [ARG]...]')
	println('Run COMMAND with an adjusted niceness, which affects process scheduling.')
	println('With no COMMAND, print the current niceness.')
	println('')
	println('  -n, --adjustment=N   add integer N to the niceness (default 10)')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
