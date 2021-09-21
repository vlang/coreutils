import os
import common

// Exit status:
// ...
fn main() {
	mut exit_code := 0
	mut fp := common.flag_parser(os.args)
	fp.application('arch')
	fp.description('Print machine architecture.')
	fp.limit_free_args_to_exactly(0) ?
	fp.remaining_parameters()
	// Main functionality
	println(os.uname().machine)
	exit(exit_code)
}
