module true

import common

const app_name = 'true'

// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
pub fn run(args []string) int {
	mut fp := common.flag_parser(args)
	fp.application(app_name)
	fp.description('Exit with a status code indicating success.')
	fp.limit_free_args(0, 0) or { return 1 }
	fp.finalize() or {}
	return 0
}
