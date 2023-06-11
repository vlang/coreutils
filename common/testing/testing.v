module testing

import os
import regex

// The ...Error structs here implement IError,
// so that they can be used as more specific errors,
// in place of `return error(message)`
struct DidNotFailError {
	Error
	msg  string
	code int
}

pub fn (err DidNotFailError) msg() string {
	return err.msg
}

pub fn (err DidNotFailError) code() int {
	return err.code
}

struct DoesNotWorkError {
	Error
	msg  string
	code int
}

pub fn (err DoesNotWorkError) msg() string {
	return err.msg
}

pub fn (err DoesNotWorkError) code() int {
	return err.code
}

struct ExitCodesDifferError {
	Error
	msg  string
	code int
}

pub fn (err ExitCodesDifferError) msg() string {
	return err.msg
}

pub fn (err ExitCodesDifferError) code() int {
	return err.code
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
	return same_results('${p.original} ${options}', '${p.deputy} ${options}')
}

// expected_failure - given some options, execute both the original
// and the deputy commands with them, and ensure that they both fail
// with the same exit_code
pub fn (p CommandPair) expected_failure(options string) ?os.Result {
	ores := os.execute('${p.original} ${options}')
	if ores.exit_code == 0 {
		return DidNotFailError{
			msg: '${p.original} ${options}'
			code: 1
		}
	}
	dres := os.execute('${p.deputy} ${options}')
	if dres.exit_code == 0 {
		return DidNotFailError{
			msg: '${p.deputy} ${options}'
			code: 2
		}
	}
	if ores.exit_code != dres.exit_code {
		return ExitCodesDifferError{
			msg: 'original.exit_code: ${ores.exit_code} != deputy.exit_code: dres.exit_code'
			code: 1
		}
	}
	assert true
	return dres
}

pub fn (p CommandPair) ensure_help_and_version_options_work() ! {
	// For now, assume that the original has --version and --help
	// and that they already work correctly.
	if os.execute('${p.deputy} --help').exit_code != 0 {
		return DoesNotWorkError{
			msg: '--help'
			code: 1
		}
	}
	if os.execute('${p.deputy} --version').exit_code != 0 {
		return DoesNotWorkError{
			msg: '--version'
			code: 2
		}
	}
	assert true
}

// command_fails executes a command, and ensures
// that its exit code is not 0 (i.e. the command failed)
// It also returns the actual result of the execution,
// so that you can inspect it further for more details.
pub fn command_fails(cmd string) !os.Result {
	res := os.execute(cmd)
	if res.exit_code == 0 {
		return DidNotFailError{
			msg: cmd
			code: 3
		}
	}
	assert true
	return res
}

const gnu_coreutils_installed = os.getenv('GNU_COREUTILS_INSTALLED').int() == 1

// same_results/2 executes the given commands, and ensures that
// their results are exactly the same, both for their exit codes,
// and for their output.
// note: use `v -d trace_same_results ...` to enable trace output
pub fn same_results(cmd1 string, cmd2 string) bool {
	mut cmd1_res := os.execute(cmd1)
	mut cmd2_res := os.execute(cmd2)
	mut noutput1 := normalise(cmd1_res.output)
	mut noutput2 := normalise(cmd2_res.output)
	$if trace_same_results ? {
		eprintln('------------------------------------')
		eprintln('>> same_results cmd1: "${cmd1}"')
		eprintln('>> same_results cmd2: "${cmd2}"')
		eprintln('                cmd1_res.exit_code: ${cmd1_res.exit_code}')
		eprintln('                cmd2_res.exit_code: ${cmd2_res.exit_code}')
		eprintln('                cmd1_res.output.len: ${noutput1.len} | "${noutput1}"')
		eprintln('                cmd2_res.output.len: ${noutput2.len} | "${noutput2}"')
		eprintln('        (raw) > cmd1_res.output.len: ${cmd1_res.output.len} | "${cmd1_res.output}"')
		eprintln('        (raw) > cmd2_res.output.len: ${cmd2_res.output.len} | "${cmd2_res.output}"')
	}
	if testing.gnu_coreutils_installed {
		// aim for 1:1 output compatibility:
		return cmd1_res.exit_code == cmd2_res.exit_code && cmd1_res.output == cmd2_res.output
	}
	// relax the strict matching for well known exceptions:
	if cmd1.contains('coreutils') {
		noutput1 = noutput1.replace("'coreutils ", "'")
		// noutput2 = noutput2
		$if trace_same_results ? {
			eprintln('                 (coreutils) after1: ${noutput1.len} | "${noutput1}"')
			eprintln('                 (coreutils) after2: ${noutput2.len} | "${noutput2}"')
		}
	}
	if cmd1.contains('arch') {
		// `arch` is not standardized and 'AMD64' is more commonly known as 'x86_64'
		mut re := regex.regex_opt('[aA][mM][dD]64') or { panic(err) }
		// noutput1 = noutput1
		noutput2 = re.replace(noutput2, 'x86_64')
		$if trace_same_results ? {
			eprintln('                 (arch) after1: ${noutput1.len} | "${noutput1}"')
			eprintln('                 (arch) after2: ${noutput2.len} | "${noutput2}"')
		}
	}
	if cmd1.contains('printenv') && cmd2.contains('printenv.exe') {
		return cmd1_res.exit_code == cmd2_res.exit_code
	}
	if cmd1.contains('sleep') {
		noutput1 = noutput1.replace(': invalid float literal', '')
		// noutput2 = noutput2
		$if trace_same_results ? {
			eprintln('                (sleep) after1: ${noutput1.len} | "${noutput1}"')
			eprintln('                (sleep) after2: ${noutput2.len} | "${noutput2}"')
		}
	}
	if cmd1.contains('uname') {
		// `uname` is not standardized and 'AMD64' is more commonly known as 'x86_64'
		mut re := regex.regex_opt('[aA][mM][dD]64') or { panic(err) }
		// noutput1 = noutput1
		noutput2 = re.replace(noutput2, 'x86_64')
		$if trace_same_results ? {
			eprintln('                 (arch) after1: ${noutput1.len} | "${noutput1}"')
			eprintln('                 (arch) after2: ${noutput2.len} | "${noutput2}"')
		}
	}
	if cmd1 == 'uptime' || cmd1 == 'uptime /var/log/wtmp' {
		noutput1 = cmd1_res.output.all_after('load average:')
		noutput2 = cmd2_res.output.all_after('load average:')
		$if trace_same_results ? {
			eprintln('               (uptime) after1: ${noutput1.len} | "${noutput1}"')
			eprintln('               (uptime) after2: ${noutput2.len} | "${noutput2}"')
		}
	}
	// in all other cases, compare the normalised output (less strict):
	return cmd1_res.exit_code == cmd2_res.exit_code && noutput1 == noutput2
}

fn normalise(s string) string {
	return s.replace_each(['‘', "'", '’', "'"]).replace('  ', ' ').replace('  ', ' ').replace('  ',
		' ').replace(', ', ' ').split_into_lines().join('\n').trim_space()
}

pub fn check_dir_exists(d string) bool {
	return os.exists(d) && os.is_dir(d)
}

pub fn output_eol() string {
	$if windows {
		// WinOS => CRLF
		return '\r\n'
	}
	// POSIX => LF
	return '\n'
}
