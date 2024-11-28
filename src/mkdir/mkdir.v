import os
import common

const name = 'mkdir'
const space_char = u8(32)
const default_mode = u32(0o777)

struct Options {
	mode    u32
	parent  bool
	verbose bool
}

// Print messages and exit
@[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

fn mkdir_cmd(files []string, opts &Options) {
	mut num_fails := 0
	for f in files {
		if opts.parent {
			os.mkdir_all(f, mode: opts.mode) or {
				num_fails++
				eprintln('${name}: ${f}: ${err.msg()}')
				continue
			}
			announce_creation(f, opts.verbose)
			continue
		}

		// Ensure that the target dir to create's parent dir exists.
		if !os.exists(os.dir(f)) {
			eprintln("${name}: cannot create directory '${f}': No such file or directory")
			num_fails++
			continue
		}

		os.mkdir(f, mode: opts.mode) or {
			eprintln("${name}: cannot create directory '${f}': File exists")
			num_fails++
			continue
		}
		announce_creation(f, opts.verbose)
	}

	if num_fails == files.len {
		exit(1)
	}
}

fn announce_creation(f string, verbose bool) {
	if verbose {
		println("${name}: created directory '${f}'")
	}
}

fn run_mkdir(args []string) {
	mut fp := common.flag_parser(args)
	fp.application(name)
	fp.usage_example('[OPTION]... DIRECTORY...')
	fp.description('Create the DIRECTORY(ies), if they do not already exist.')
	fp.description('Mandatory arguments to long options are mandatory for short options too.')

	mut opts := Options{
		mode:    u32(fp.int('mode', `m`, int(default_mode), 'set file mode (as in chmod), not a=rxw - umask'))
		parent:  fp.bool('parents', `p`, false, 'no error if existing, make parent directories as needed')
		verbose: fp.bool('verbose', `v`, false, 'print a message for each created directory')
	}

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('${name} ${common.coreutils_version()}')
	}

	file_args := fp.finalize() or { common.exit_with_error_message(name, err.msg()) }
	if file_args.len == 0 {
		eprintln('${name}: missing operand')
		eprintln("Try '${name} --help' for more information")
		exit(1)
	}

	mkdir_cmd(file_args, &opts)
}

fn main() {
	run_mkdir(os.args)
}
