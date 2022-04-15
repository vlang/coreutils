import os
import common

const (
	app_name        = 'hostname'
	app_description = 'Prints or set the name of the current host system.'
)

/*
** GNU Coreutils Hostname clone made in V
** This is a reimplementation of the GNU Coreutils hostname command
** Like GNU, it only supports getting and set the current hostname
**
** Original author: Benoît <SheatNoisette> Malhomme
*/

// Error enum for set hostname
pub enum HostnameError {
	invalid_address
	invalid_value
	missing_permissions
	unsupported
	unknown
}

// Set the hostname, return true if success
// SUSv2 guarantees that ‘Host names are limited to 255 bytes’
// For linux targets, vlib hardcode 256 bytes for getting hostnames
fn hst_set_hostname(hostname string) {
	if hostname.len > 255 {
		common.exit_with_error_message(app_name, 'Hostname length is invalid')
	}

	if set_hostname(hostname) != 0 {
		// Fancy error printing
		message := match errno_get_hostname() {
			.invalid_address { 'The hostname defined is an invalid address.' }
			.invalid_value { 'The host name is invalid.' }
			.missing_permissions { 'An error occured while changing host name, are you root ?' }
			.unsupported { 'Setting hostname is not currently supported on your OS.' }
			else { 'An unknown error occured' }
		}
		common.exit_with_error_message(app_name, message)
	}
}

// Entry point
// Usage: ./hostname: Get the host name
// Usage: ./hostname <name>: Set the hostname as 'name'
fn main() {
	mut fp := common.flag_parser(os.args)
	fp.application(app_name)
	fp.description(app_description)

	additional_args := fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		return
	}

	// Other flags
	fp.remaining_parameters()

	if additional_args.len == 0 {
		// No args, print the hostname
		println(os.hostname())
	} else if additional_args.len == 1 {
		// Set hostname
		hst_set_hostname(additional_args[0])
	} else {
		// Forbid spaces by design - It is not recommended to use spaces in hostnames
		common.exit_with_error_message(app_name, 'Spaces are not supported for hostnames')
	}
}
