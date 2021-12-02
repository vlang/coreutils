import common
import os

const (
	app_name        = 'hostid'
	app_description = 'Print the numeric identifier (in hexadecimal) of the current host.'
)

/*
** hostid clone written in V
** Original author: B. <SheatNoisette> Malhomme
*/
fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	fp.limit_free_args(0, 0) ?

	// Get hostid using wrapper
	hostid := hd_get_hostid() & 0xffffffff

	// Print as hexadecimal
	println('$hostid.hex()')

	// Other flags
	fp.remaining_parameters()
}
