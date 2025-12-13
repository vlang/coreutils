import os
import common

const tool_name = 'nohup'
const out_files = ['nohup.out', '${os.getenv_opt('HOME')?}/nohup.out']

fn open_nohup_out(mut f os.File, print_message bool) ! {
	for file in out_files {
		mut temp := os.open_file(file, 'a', 0o600) or { continue }

		f.reopen(file, 'a')!
		temp.close()
		if print_message {
			println('info: redirecting stdout to ${file}')
		}
		return
	}
	error('could not open ${out_files.join(' or ')}')
}

fn usage() {
	print('Usage: ${tool_name} [OPTION]
	      |       ${tool_name} [COMMAND]
	      |Options:
	      |    -h, --help     Shows help
	      |    -v, --version  Shows version'.strip_margin())
	println(common.coreutils_footer())
	exit(0)
}

fn main() {
	if os.args.len == 1 {
		usage()
	}
	// a custom arg parser instead of the one in common is needed
	// because the command may contain -h
	// and the common parser gets messed up
	match os.args[1..] {
		['-h'], ['--help'] {
			usage()
		}
		['-v'], ['--version'] {
			println(tool_name + ' ' + common.coreutils_version())
			return
		}
		else {}
	}

	command := os.args[1..]
	// do this early before we loose access to stderr
	if os.exists_in_system_path(command[0]) == false {
		common.exit_with_error_message(tool_name, '${command[0]} does not exist or is not executable')
	}

	stdout_is_tty := os.is_atty(os.stdout().fd)

	if os.is_atty(os.stdin().fd) == 1 {
		mut f := os.stdin()
		println('info: redirecting stdin from tty to /dev/null')
		f.reopen('/dev/null', 'rw')!
	}
	if stdout_is_tty == 1 {
		mut f := os.stdout()
		open_nohup_out(mut f, true) or { common.exit_with_error_message(tool_name, err.msg()) }
	}
	if os.is_atty(os.stderr().fd) == 1 {
		if os.stdout().is_opened == false {
			mut f := os.stderr()
			open_nohup_out(mut f, false) or { common.exit_with_error_message(tool_name, err.msg()) }
		} else {
			// couldn't find a v equilavent of this
			C.dup2(os.stdout().fd, os.stderr().fd)
		}
	}

	os.execvp(command[0], command[1..])!
}
