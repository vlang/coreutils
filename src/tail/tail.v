// tail - output the last part of files
import common
import flag
import os
import time
import v.mathutil

const app_name = 'tail'

fn main() {
	args := get_args(os.args)
	tail(args, fn (s string) {
		print(s)
		flush_stdout()
	})
}

fn tail(args Args, out_fn fn (string)) {
	mut tail_forever := false
	mut files := args.files.map(FileInfo{ name: it })

	for {
		for i, mut file in files {
			stat := os.stat(file.name) or {
				if args.retry {
					continue
				}
				exit_error(err.msg())
			}

			if stat.size < file.size {
				out_fn('\n===> ${file.name} truncated <===\n')
			} else if stat.size != file.size {
				leading_line_feeds := i > 0 || (tail_forever && args.files.len > 1)
				file_header(file.name, leading_line_feeds, args, out_fn)

				match true {
					tail_forever { append_new_bytes(file, out_fn) }
					args.bytes > 0 { tail_bytes(file, args, stat.size, out_fn) }
					args.lines > 0 { tail_file(file, args, stat.size, out_fn) }
					else { exit_error('invalid state') }
				}
			}

			file.size = stat.size
		}

		if args.follow {
			tail_forever = true
			time.sleep(i64(args.sleep_interval * time.second))
			if args.pid.len > 0 {
				result := os.execute('ps ${args.pid}')
				if result.exit_code != 0 {
					break
				}
			}
			continue
		}
		break
	}
}

fn file_header(file string, leading_line_feeds bool, args Args, out_fn fn (string)) {
	if leading_line_feeds {
		out_fn('\n\n')
	}
	if args.quiet {
		return
	}
	if args.files.len > 1 || args.verbose {
		out_fn('===> ${file} <===\n')
	}
}

fn tail_bytes(file FileInfo, args Args, stat_size u64, out_fn fn (string)) {
	pos := if args.from_start {
		args.bytes
	} else {
		mathutil.max(u64(0), stat_size - u64(args.bytes))
	}
	mut f := os.open(file.name) or {
		if args.retry {
			return
		}
		exit_error(err.msg())
	}
	defer { f.close() }
	print_file_at(f, pos, out_fn)
}

fn tail_file(file FileInfo, args Args, stat_size u64, out_fn fn (string)) {
	mut f := os.open(file.name) or {
		if args.retry {
			return
		}
		exit_error(err.msg())
	}
	defer { f.close() }

	buf_size := i64(4096)
	mut buf := []u8{len: int(buf_size)}
	mut count := 0
	end := i64(stat_size)

	if args.from_start {
		mut pos := i64(0)

		loop1: for pos <= end {
			len := mathutil.min(end - pos, buf_size)
			f.read_bytes_into(u64(pos), mut buf) or { exit_error(err.msg()) }

			for i := 0; i < len; i += 1 {
				if buf[i] == args.delimiter {
					count += 1
					if count >= args.lines - 1 {
						pos = pos + i + 1
						break loop1
					}
				}
			}

			pos += buf_size + 1
		}

		print_file_at(f, pos, out_fn)
	} else {
		mut pos := end

		loop2: for pos > 0 {
			len := mathutil.min(pos, buf_size)
			pos = mathutil.max(pos - buf_size, 0)
			f.read_bytes_into(u64(pos), mut buf) or { exit_error(err.msg()) }

			for i := len - 1; i >= 0; i -= 1 {
				if buf[i] == args.delimiter {
					count += 1
					if count >= args.lines {
						pos = pos + i + 1
						break loop2
					}
				}
			}
		}

		print_file_at(f, pos, out_fn)
	}
}

fn print_file_at(file os.File, pos i64, out_fn fn (string)) {
	mut idx := pos
	buf_size := 4096
	mut buf := []u8{len: buf_size}
	mut bytes_read := buf_size

	for bytes_read == buf_size {
		bytes_read = file.read_bytes_into(u64(idx), mut buf) or { exit_error(err.msg()) }
		out_fn(buf[0..bytes_read].bytestr())
		idx += bytes_read
	}
}

struct FileInfo {
	name string
pub mut:
	size u64
}

fn append_new_bytes(file FileInfo, out_fn fn (string)) {
	mut f := os.open(file.name) or { exit_error(err.msg()) }
	defer { f.close() }
	print_file_at(f, file.size, out_fn)
}

struct Args {
	bytes               i64
	follow              bool
	lines               i64
	pid                 string
	quiet               bool
	retry               bool
	sleep_interval      f64
	verbose             bool
	from_start          bool
	delimiter           u8 = `\n`
	files               []string
}

fn get_args(args []string) Args {
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

	bytes_arg := fp.string('bytes', `c`, '-1',
		'output the last NUM bytes; or use -c +<int> to output      ${wrap}' +
		'starting with byte <int> of each file')

	follow_arg := fp.bool('follow', `f`, false, 'output appended data as the file grows')
	f_arg := fp.bool('', `F`, false, 'same as --follow=name --retry')

	lines_arg := fp.string('lines', `n`, '10',
		'output the last NUM lines, instead of the last 10; or us${wrap}' +
		'-n +NUM to skip NUM-1 lines at the start')

	pid_arg := fp.string('pid', ` `, '', 'with -f, terminate after process ID, PID dies')
	quiet_arg := fp.bool('quiet', `q`, false, 'never output headers giving file names')
	silent_arg := fp.bool('silent', ` `, false, 'same as --quiet')
	retry_arg := fp.bool('retry', ` `, false, 'keep trying to open a file if it is inaccessible')

	sleep_interval_arg := fp.float('sleep-interval', `s`, 1.0,
		'with -f, sleep for approximately N seconds (default 1.0)${wrap}' +
		'between iterations; with inotify and --pid=P, check${wrap}' +
		'process P at least once every N seconds')

	verbose_arg := fp.bool('verbose', `v`, false, 'always output headers giving file names')
	zero_terminated_arg := fp.bool('zero-terminated', `z`, false, 'line delimiter is NUL, not newline')

	fp.footer("

		NUM may have a multiplier suffix: b 512, kB 1000, K 1024, MB
		1000*1000, M 1024*1024, GB 1000*1000*1000, G 1024*1024*1024, and
		so on for T, P, E, Z, Y, R, Q. Binary prefixes can be used, too:
		KiB=K, MiB=M, and so on.

		This implementation of TAIL follows files by name only. File
		descriptors are not supported".trim_indent())

	fp.footer(common.coreutils_footer())
	file_args := fp.finalize() or { exit_error(err.msg()) }
	from_start := bytes_arg.starts_with('+') || lines_arg.starts_with('+')
	delimiter := if zero_terminated_arg { `\0` } else { `\n`}

	return Args{
		bytes: string_to_i64(bytes_arg) or { exit_error(err.msg()) }
		follow: follow_arg
		lines: string_to_i64(lines_arg) or { exit_error(err.msg()) }
		pid: pid_arg
		quiet: quiet_arg || silent_arg
		retry: f_arg || retry_arg
		verbose: verbose_arg
		sleep_interval: sleep_interval_arg
		from_start: from_start
		delimiter: delimiter
		files: file_args
	}
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
