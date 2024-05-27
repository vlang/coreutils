// tail - output the last part of files
import common
import flag
import os

const app_name = 'tail'

fn main() {
	get_args(os.args)
}

fn get_args(args []string) {
	mut fp := flag.new_flag_parser(args)

	fp.application(app_name)
	fp.version(common.coreutils_version())
	fp.skip_executable()
	fp.description('
		Print the last 10 lines of each FILE to standard output.
		With more than one FILE, precede each with a header giving the file name.

		With no FILE, or when FILE is -, read standard input.'.trim_indent())

	eol := common.eol()
	wrap := eol + flag.space

	fp.string('bytes', `c`, '',
		'output the last NUM bytes; or use -c +<int> to output      ${wrap}' +
		'starting with byte <int> of each file')
	fp.string('follow', `f`, 'descriptor',
		'output appended data as the file grows        ${wrap}' +
		"an absent option argument means 'descriptor'")
	fp.bool('', `F`, false, 'same as --follow=name --retry')
	fp.string('lines', `n`, '10',
		'output the last NUM lines, instead of the last 10; or us${wrap}' +
		'-n +NUM to skip NUM-1 lines at the start')
	fp.int('max-unchanged-stats', ` `, 5,
		'with --follow=name, reopen a FILE which has not${wrap}' +
		'changed size after N (default 5) iterations to see if it${wrap}' +
		'has been unlinked or renamed (this is the usual case of${wrap}' +
		'rotated log files); with inotify, this option is rarely usefule')
	fp.string('pid', ` `, '', 'with -f, terminate after process ID, PID dies')
	fp.bool('quiet', `q`, false, 'never output headers giving file names')
	fp.bool('silent', ` `, false, 'same as --quiet')
	fp.bool('retry', ` `, false, 'keep trying to open a file if it is inaccessible')
	fp.float('sleep-interval', `s`, 1.0,
		'with -f, sleep for approximately N seconds (default 1.0)${wrap}' +
		'between iterations; with inotify and --pid=P, check${wrap}' +
		'process P at least once every N seconds')
	fp.bool('verbose', `v`, false, 'always output headers giving file names')
	fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	fp.footer("

		NUM may have a multiplier suffix: b 512, kB 1000, K 1024, MB
		1000*1000, M 1024*1024, GB 1000*1000*1000, G 1024*1024*1024, and
		so on for T, P, E, Z, Y, R, Q.  Binary prefixes can be used, too:
		KiB=K, MiB=M, and so on.

		With --follow (-f), tail defaults to following the file
		descriptor, which means that even if a tail'ed file is renamed,
		tail will continue to track its end.  This default behavior is
		not desirable when you really want to track the actual name of
		the file, not the file descriptor (e.g., log rotation).  Use
		--follow=name in that case.  That causes tail to track the named
		file in a way that accommodates renaming, removal and creation.".trim_indent())

	fp.footer(common.coreutils_footer())
	fp.finalize() or { exit_error(err.msg()) }
}

@[noreturn]
fn exit_success(msg string) {
	println(msg)
	exit(0)
}

@[noreturn]
fn exit_error(msg string) {
	common.exit_with_error_message(app_name, msg)
}
