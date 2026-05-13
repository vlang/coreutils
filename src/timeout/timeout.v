module main

import common
import os
import time

const app_name = 'timeout'

const signal_names = {
	'HUP':    1
	'INT':    2
	'QUIT':   3
	'ILL':    4
	'TRAP':   5
	'ABRT':   6
	'BUS':    7
	'FPE':    8
	'KILL':   9
	'USR1':   10
	'SEGV':   11
	'USR2':   12
	'PIPE':   13
	'ALRM':   14
	'TERM':   15
	'CHLD':   17
	'CONT':   18
	'STOP':   19
	'TSTP':   20
	'TTIN':   21
	'TTOU':   22
	'URG':    23
	'XCPU':   24
	'XFSZ':   25
	'VTALRM': 26
	'PROF':   27
	'WINCH':  28
}

struct TimeoutOptions {
	cmd_args        []string
	duration_ms     i64
	kill_after_ms   i64
	signal          string
	preserve_status bool
	verbose         bool
	foreground      bool
}

fn main() {
	exit(timeout_fn())
}

fn timeout_fn() int {
	mut fp := common.flag_parser(os.args)
	fp.allow_unknown_args()
	fp.application(app_name)
	fp.description('Start COMMAND, and kill it if still running after DURATION.')

	signal := fp.string('signal', `s`, 'TERM', 'specify the signal to send on timeout')
	kill_after := fp.string('kill-after', `k`, '', 'also send a KILL signal after DURATION')
	preserve_status := fp.bool('preserve-status', 0, false,
		'exit with the same status as COMMAND, even when timeout occurs')
	verbose := fp.bool('verbose', `v`, false, 'diagnose to stderr any signal sent upon timeout')
	foreground := fp.bool('foreground', 0, false,
		'run command in foreground without creating new process group')
	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')

	args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return 125
	}

	if help {
		println(fp.usage())
		return 0
	}

	if version {
		println('${app_name} ${common.coreutils_version()}')
		return 0
	}

	if args.len < 2 {
		eprintln('${app_name}: missing operand')
		println(fp.usage())
		return 125
	}

	duration_str := args[0]
	cmd_args := args[1..]

	duration_ms := parse_duration(duration_str) or {
		eprintln('${app_name}: invalid duration: ${duration_str}')
		return 125
	}

	kill_after_ms := if kill_after != '' {
		parse_duration(kill_after) or {
			eprintln('${app_name}: invalid kill-after duration: ${kill_after}')
			return 125
		}
	} else {
		0
	}

	if duration_ms == -1 && kill_after_ms > 0 {
		eprintln('${app_name}: cannot use --kill-after with infinite duration')
		return 125
	}

	opts := TimeoutOptions{
		cmd_args:        cmd_args
		duration_ms:     duration_ms
		kill_after_ms:   kill_after_ms
		signal:          signal
		preserve_status: preserve_status
		verbose:         verbose
		foreground:      foreground
	}

	return run_timeout(opts)
}

// Duration string -> milliseconds
fn parse_duration(s string) !i64 {
	mut num_str := ''
	mut suffix := 's'

	if s == '0' || s == 'infinity' {
		return -1
	} else if s == '' {
		return error('empty duration')
	} else if s.starts_with('-') {
		return error('duration cannot be negative')
	}

	for i, c in s {
		if c.is_digit() || c == `.` {
			num_str += c.ascii_str()
		} else {
			suffix = s[i..]
			break
		}
	}

	if num_str == '' {
		return error('missing number in duration')
	}

	for c in num_str {
		if !c.is_digit() && c != `.` {
			return error('invalid number: ${num_str}')
		}
	}

	val := num_str.f64()
	if val < 0 {
		return error('duration cannot be negative')
	}

	multiplier := match suffix {
		's' { 1000 }
		'm' { 60000 }
		'h' { 3600000 }
		'd' { 86400000 }
		else { return error('invalid suffix: ${suffix}') }
	}

	return i64(val * multiplier)
}

// Signal string into signal number
fn parse_signal(s string) !int {
	if s == '' {
		return error('empty signal')
	}

	// If it's a number
	if s[0].is_digit() {
		sig_num := s.int()
		if sig_num < 1 || sig_num > 64 {
			return error('signal number out of range: ${sig_num}')
		}
		return sig_num
	}

	// Remove SIG prefix if present
	mut name := s.to_upper()
	if name.starts_with('SIG') {
		name = name[3..]
	}

	// Look up
	if name in signal_names {
		return signal_names[name]
	}
	return error('invalid signal: ${s}')
}

// Finds the executable and starts the subprocess
fn start_process(cmd_args []string, foreground bool) !&os.Process {
	cmd_path := os.find_abs_path_of_executable(cmd_args[0]) or {
		// Check if file exists but not executable
		abs_path := os.abs_path(cmd_args[0])
		if os.exists(abs_path) {
			return error('permission denied')
		}
		return error('command not found')
	}

	mut p := os.new_process(cmd_path)
	p.args = cmd_args[1..]
	p.run()
	if !p.is_alive() {
		return error('failed to start process')
	}

	setup_process_group(p, foreground)
	return p
}

// Waits for the process and returns the appropriate exit code
fn handle_process_exit(mut p os.Process, preserve_status bool, success_exit int) int {
	p.wait()

	code := if p.code < 0 {
		// p.code is -signal, so 128 + signal
		128 - p.code
	} else {
		p.code
	}

	if preserve_status {
		return code
	} else {
		return success_exit
	}
}

// Signal on timeout and handles kill after if specified
fn handle_timeout(mut p os.Process, kill_after_ms i64, signal string, preserve_status bool, verbose bool, foreground bool) int {
	sig_num := parse_signal(signal) or {
		eprintln('${app_name}: invalid signal: ${signal}')
		return 125
	}

	if verbose {
		eprintln('${app_name}: sending signal ${signal} to command')
	}
	terminate_process(p, sig_num, !foreground)

	if kill_after_ms > 0 {
		kill_start := time.now()
		for {
			if !p.is_alive() {
				return handle_process_exit(mut p, preserve_status, 124)
			}
			time.sleep(10 * time.millisecond)
			if time.since(kill_start) > kill_after_ms * time.millisecond {
				if p.is_alive() {
					if verbose {
						eprintln('${app_name}: sending signal KILL to command')
					}
					terminate_process(p, 9, !foreground)
				}
				return handle_process_exit(mut p, preserve_status, 124)
			}
		}
	} else {
		return handle_process_exit(mut p, preserve_status, 124)
	}

	// unreachable
	return 0
}

// Monitors subprocess and handles timeout or normal exit
fn run_timeout(opts TimeoutOptions) int {
	mut p := start_process(opts.cmd_args, opts.foreground) or {
		eprintln('${app_name}: ${err}')
		if err.str() == 'permission denied' {
			return 126
		}
		return 127
	}

	start := time.now()
	for {
		if !p.is_alive() {
			return handle_process_exit(mut p, opts.preserve_status, 0)
		}
		time.sleep(10 * time.millisecond)
		if opts.duration_ms > 0 && time.since(start) > opts.duration_ms * time.millisecond {
			return handle_timeout(mut p, opts.kill_after_ms, opts.signal, opts.preserve_status,
				opts.verbose, opts.foreground)
		}
	}

	// Unreachable
	return 0
}
