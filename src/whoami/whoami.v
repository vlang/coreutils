import os
import common

fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application('whoami')
	fp.description('Print the user name associated with the current effective user ID.')
	fp.description('Same as id -un.')
	fp.limit_free_args_to_exactly(0)!
	fp.remaining_parameters()
	username := whoami() or { common.exit_with_error_message('whoami', err.msg()) }
	println(username)
}
