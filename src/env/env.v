// env - run a program in a modified environment
import os
import maps

fn main() {
	args := new_args(os.args) or {
		eprintln(err)
		return
	}
	run(args)
}

pub fn run(args EnvArg) {
	mut envs := if args.ignore {
		map[string]string{}
	} else {
		os.environ()
	}

	for key in args.unsets {
		envs.delete(key)
	}

	if args.cmd_args.len == 0 {
		eol := if args.nul_terminated { '\0' } else { '\n' }
		for key, val in envs {
			print('${key}=${val}' + eol)
		}
		return
	}

	cmd_path := os.find_abs_path_of_executable(args.cmd_args[0]) or {
		eprintln(err)
		return
	}

	os.execve(cmd_path, args.cmd_args[1..], maps.to_array(envs, fn (k string, v string) string {
		return '${k}=${v}\0'
	})) or { eprintln(err) }
}
