import os
import common

const out_files = ['nohup.out', '${os.getenv_opt('HOME')!}/nohup.out']

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('nohup')
	fp.description('Run a command, ignoring hangup signals')
	fp.limit_free_args_to_at_least(1)!
	command := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	// do this early before we loose access to stderr
	if os.exists_in_system_path(command[0]) == false {
		eprintln('fatal: ${command[0]} does not exist or is not executable')
	}

	stdout_is_tty := os.is_atty(os.stdout().fd)

	if os.is_atty(os.stdin().fd) == 1 {
		mut f := os.stdin()
		f.reopen('/dev/null', 'rw')!
	}
	if stdout_is_tty == 1 {
		mut f := os.stdout()

		for file in out_files {
			mut temp := os.open_file(file, 'a', 0o600) or { continue }

			println('info: redirecting stdout to ${file}')
			f.reopen(file, 'a')! // from this point on stdout goes to nohup.out
			temp.close()
			break
		}
	}
	if os.is_atty(os.stderr().fd) == 1 {
		if os.stdout().is_opened == false {
			mut f := os.stderr()
			f.reopen('nohup.out', 'rw') or {
				f.reopen('${os.getenv_opt('HOME')!}/nohup.out', 'rw')!
			}
		} else {
			// couldn't find a v equilavent of this
			C.dup2(os.stdout().fd, os.stderr().fd)
		}
	}

	os.execvp(command[0], command[1..])!
}
