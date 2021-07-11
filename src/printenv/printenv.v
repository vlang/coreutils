import os
import flag
import common

const zero_byte = byte(0).ascii_str()

// Exit status:
// 0 if all variables specified were found
// 1 if at least one specified variable was not found
// 2 if a write error occurred
fn main() {
	mut exit_code := 0
	mut fp := common.flag_parser(os.args)
	fp.application('printenv')
	fp.arguments_description('[VARIABLE]...')
	fp.description('Print the values of the specified environment VARIABLE(s).')
	fp.description('If no VARIABLE is specified, print name and value pairs for them all.')
	mut opt_nul_terminate := fp.bool('null', `0`, false, 'end each output line with NUL, not newline')
	if opt_nul_terminate {
		if os.args[1] !in ['-0', '--null'] {
			// GNU printenv has a quirk,
			// where -0 when it is not the first option
			// only changes the exit_code to 1, but does
			// *NOT* affect the output
			opt_nul_terminate = false
			exit_code = 1
		}
	}
	args := fp.remaining_parameters()

	// Main functionality
	if args.len == 0 {
		for k, v in os.environ() {
			mut s := '$k=$v'
			if opt_nul_terminate {
				print(s)
				print(zero_byte)
			} else {
				println(s)
			}
		}
	} else {
		for k in args {
			mut v := os.getenv(k)
			if v == '' {
				exit_code = 1 // at least one specified variable was not found
				continue
			}
			if opt_nul_terminate {
				print(v)
				print(zero_byte)
			} else {
				println(v)
			}
		}
	}
	exit(exit_code)
}
