import common

const (
	name = 'cp'
)
 
// Print messages and exit with error
[noreturn]
fn error_exit(messages ...string) {
	for message in messages {
		eprintln(message)
	}
	exit(1)
}

// Print messages and exit
[noreturn]
fn success_exit(messages ...string) {
	for message in messages {
		println(message)
	}
	exit(0)
}

fn setup_cp_command(args []string) ?(CpCommand, []string, string) {
	mut fp := common.flag_parser(args)
	fp.application('cp')
	fp.limit_free_args_to_at_least(1)

	help := fp.bool('help', 0, false, 'display this help and exit')
	version := fp.bool('version', 0, false, 'output version information and exit')
	if help {
		success_exit(fp.usage())
	}
	if version {
		success_exit('$name $common.coreutils_version()')
	}

	sources := []string{}
	dest := ''
	return CpCommand{}, sources, dest
}

fn run_cp(args []string) {
	cp, sources, dest := setup_cp_command(args) or { common.exit_with_error_message(name, err.msg) }
	// println('running cp')
}
