module arch

import os
import common

// Exit status:
// ...
// run is the entry point shared by the standalone binary and the multicall
// binary, so both dispatch through the same code.
pub fn run(args []string) int {
	mut fp := common.flag_parser(args)
	fp.application('arch')
	fp.description('Print machine architecture.')
	fp.limit_free_args_to_exactly(0) or { return 1 }
	fp.remaining_parameters()
	println(os.uname().machine)
	return 0
}
