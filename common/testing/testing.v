module testing

import os

// The ...Error structs here implement IError,
// so that they can be used as more specific errors,
// in place of `return error(message)`
struct DidNotFailError {
	msg  string
	code int
}

struct DoesNotWorkError {
	msg  string
	code int
}

struct ExitCodesDifferError {
	msg  string
	code int
}

// CommandPair remembers what original command we are trying to test against
pub struct CommandPair {
pub mut:
	original string // the system command (the GNU version)
	deputy   string // the V coreutils command (which should behave more or less the same)
}

// new_paired_command creates a new command pair, that is a structure,
// recording that a given command (the `original`) has been implemented
// in another executable (the `deputy`). The deputy should have the same
// behaviour more or less as the original.
pub fn new_paired_command(original string, deputy string) CommandPair {
	return CommandPair{
		original: original
		deputy: deputy
	}
}

// same_results - given some options, execute both the original
// and the deputy commands, and ensure that their results match
pub fn (p CommandPair) same_results(options string) bool {
	if options.len == 0 {
		return same_results(p.original, p.deputy)
	}
	return same_results('$p.original $options', '$p.deputy $options')
}

// expected_failure - given some options, execute both the original
// and the deputy commands with them, and ensure that they both fail
// with the same exit_code
pub fn (p CommandPair) expected_failure(options string) ?os.Result {
	ores := os.execute('$p.original $options')
	if ores.exit_code == 0 {
		return IError(DidNotFailError{'$p.original $options', 1})
	}
	dres := os.execute('$p.deputy $options')
	if dres.exit_code == 0 {
		return IError(DidNotFailError{'$p.deputy $options', 2})
	}
	if ores.exit_code != dres.exit_code {
		return IError(ExitCodesDifferError{'original.exit_code: $ores.exit_code != deputy.exit_code: dres.exit_code', 1})
	}
	return dres
}

pub fn (p CommandPair) ensure_help_and_version_options_work() ? {
	// For now, assume that the original has --version and --help
	// and that they already work correctly.
	if os.execute('$p.deputy --help').exit_code != 0 {
		return IError(DoesNotWorkError{'--help', 1})
	}
	if os.execute('$p.deputy --version').exit_code != 0 {
		return IError(DoesNotWorkError{'--version', 2})
	}
}

// command_fails executes a command, and ensures
// that its exit code is not 0 (i.e. the command failed)
// It also returns the actual result of the execution,
// so that you can inspect it further for more details.
pub fn command_fails(cmd string) ?os.Result {
	res := os.execute(cmd)
	if res.exit_code == 0 {
		return IError(DidNotFailError{cmd, 3})
	}
	return res
}

const gnu_coreutils_installed = os.getenv('GNU_COREUTILS_INSTALLED').int() == 1

// same_results/2 executes the given commands, and ensures that
// their results are exactly the same, both for their exit codes,
// and for their output.
pub fn same_results(cmd1 string, cmd2 string) bool {
	mut cmd1_res := os.execute(cmd1)
	mut cmd2_res := os.execute(cmd2)
	noutput1 := normalise(cmd1_res.output)
	noutput2 := normalise(cmd2_res.output)
	$if trace_same_results ? {
		eprintln('------------------------------------')
		eprintln('>> same_results cmd1: "$cmd1"')
		eprintln('>> same_results cmd2: "$cmd2"')
		eprintln('                cmd1_res.exit_code: $cmd1_res.exit_code')
		eprintln('                cmd2_res.exit_code: $cmd2_res.exit_code')
		eprintln('                cmd1_res.output.len: $cmd1_res.output.len | "$noutput1"')
		eprintln('                cmd2_res.output.len: $cmd2_res.output.len | "$noutput2"')
		eprintln('              > cmd1_res.output.len: $cmd1_res.output.len | "$cmd1_res.output"')
		eprintln('              > cmd2_res.output.len: $cmd2_res.output.len | "$cmd2_res.output"')
	}
	if testing.gnu_coreutils_installed {
		// aim for 1:1 output compatibility:
		return cmd1_res.exit_code == cmd2_res.exit_code && cmd1_res.output == cmd2_res.output
	}
	// relax the strict matching for well known exceptions:
	if cmd1.contains('printenv') && cmd2.contains('printenv.exe') {
		return cmd1_res.exit_code == cmd2_res.exit_code
	}
	if cmd1 == 'uptime' || cmd1 == 'uptime /var/log/wtmp' {
		after1 := cmd1_res.output.all_after('load average:')
		after2 := cmd2_res.output.all_after('load average:')
		$if trace_same_results ? {
			eprintln('                after1.len: $after1.len | "$after1"')
			eprintln('                after2.len: $after2.len | "$after2"')
		}
		return cmd1_res.exit_code == cmd2_res.exit_code && after1 == after2
	}
	// in all other cases, compare the normalised output (less strict):
	return cmd1_res.exit_code == cmd2_res.exit_code && noutput1 == noutput2
}

fn normalise(s string) string {
	return s.replace_each(['‘', "'", '’', "'"]).replace('  ', ' ').replace('  ', ' ').replace('  ',
		' ').replace(', ', ' ')
}
