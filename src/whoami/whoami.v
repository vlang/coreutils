module whoami

import common

const app_name = 'whoami'

// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
pub fn run(args []string) int {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description('Print the user name associated with the current effective user ID.')
	fp.description('Same as id -un.')
	fp.limit_free_args_to_exactly(0) or { return 1 }
	fp.remaining_parameters()
	username := whoami() or {
		common.exit_with_error_message(app_name, err.msg())
		return 1
	}
	println(username)
	return 0
}
