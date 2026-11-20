import common
import os

const app_name = 'chroot'

struct Settings {
mut:
	new_root   string
	groups     []string
	userspec   string
	skip_chdir bool
	command    []string
}

fn main() {
	set := parse_args(os.args[1..])
	if set.new_root == '' {
		common.fail_with_help(app_name, 'missing operand')
	}

	// The order matters: GNU reports why it could not change root before it
	// ever tries to run the command.
	if !os.exists(set.new_root) {
		common.die(app_name, "cannot change root directory to '${set.new_root}': No such file or directory",
			125)
	}
	if !os.is_dir(set.new_root) {
		common.die(app_name, "cannot change root directory to '${set.new_root}': Not a directory",
			125)
	}

	res := change_root(set.new_root)
	if res != 0 {
		common.die(app_name, "cannot change root directory to '${set.new_root}': Operation not permitted",
			125)
	}

	if !set.skip_chdir {
		enter_root_dir()
	}

	if set.command.len == 0 {
		return
	}

	os.execvp(set.command[0], set.command[1..])!
}

fn parse_args(args []string) Settings {
	mut s := Settings{}
	mut rest := []string{}

	for i := 0; i < args.len; i++ {
		a := args[i]
		if a == '--help' {
			print_help()
			exit(0)
		}
		if a == '--version' {
			println('chroot (V coreutils) ${common.version}')
			exit(0)
		}
		if a == '--' {
			rest << args[i + 1..]
			break
		}
		if a.starts_with('--userspec=') {
			s.userspec = a['--userspec='.len..]
			continue
		}
		if a == '--userspec' && i + 1 < args.len {
			i++
			s.userspec = args[i]
			continue
		}
		if a.starts_with('--groups=') {
			s.groups << a['--groups='.len..].split(',')
			continue
		}
		if a == '--groups' && i + 1 < args.len {
			i++
			s.groups << args[i].split(',')
			continue
		}
		if a == '--skip-chdir' {
			s.skip_chdir = true
			continue
		}
		if a.starts_with('-') && a.len > 1 {
			common.exit_with_error_message(app_name, "unrecognized option '${a}'")
		}
		rest << a
	}

	// The first operand is the new root; everything after it is the command.
	if rest.len > 0 {
		s.new_root = rest[0]
		s.command = rest[1..].clone()
	}
	return s
}

fn print_help() {
	println('Usage: chroot [OPTION] NEWROOT [COMMAND [ARG]...]')
	println('  or:  chroot OPTION')
	println('Run COMMAND with root directory set to NEWROOT.')
	println('')
	println('      --groups=GROUPS        specify supplementary groups as g1,g2,..,gN')
	println('      --userspec=USER:GROUP  specify user and group (ID or name) to use')
	println('      --skip-chdir           do not change working directory to /')
	println('      --help        display this help and exit')
	println('      --version     output version information and exit')
}
