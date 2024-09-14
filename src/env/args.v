import common

const app_name = 'env'
const app_description = 'run a program in a modified environment'

struct EnvArg {
	// -0
	nul_terminated bool

	// -u
	unsets []string

	// -i
	ignore bool

	// command and arguments
	cmd_args []string
}

pub fn new_args(args []string) !EnvArg {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description(app_description)
	fp.version(common.coreutils_version())

	nul := fp.bool('null', `0`, false, 'end each output line with NUL, not newline')
	unsets := fp.string_multi('unset', `u`, 'remove variable from the environment')
	ignore := fp.bool('ignore-environment', `i`, false, 'start with an empty environment')

	cmd_args := fp.finalize() or { return err }

	return EnvArg{
		nul_terminated: nul
		unsets:         unsets
		ignore:         ignore
		cmd_args:       cmd_args
	}
}
