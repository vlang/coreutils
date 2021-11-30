import os
import runtime
import common

const (
	app_name        = 'nproc'
	app_description = 'Print the number of processing units available to the current process.'
)

/*
** Nproc clone written in V
** Original author: Benoît <SheatNoisette> Malhomme
*/

fn main() {
	// Use integrated parser
	mut fp := common.flag_parser(os.args)
	fp.application('nproc')
	fp.description('Print the number of processing units available to the current process.')

	// Get arguments
	all_flag := fp.bool('all', 0, false, 'Print the number of detected processor(s)')
	ignored_cpus := fp.int('ignore', 0, 0, 'Exclude N processing units if possible')

	// Other flags
	fp.remaining_parameters()

	// Check if ignored CPUs is > 0
	if ignored_cpus < 0 {
		println('nproc: invalid number: \'$ignored_cpus\'')
		exit(1)
	}

	// Get number of CPUs
	// If "all" flag is set, get the number of CPU configured by the system
	// else, return the number of CPU usable (which can be different).
	// ONLINE (Available) != CONFIGURED (OS)
	mut cpus := if all_flag { nb_configured_processors() } else { runtime.nr_cpus() }

	// Check number of CPU "ignored" and if "ignored" > CPU set it to 1
	if ignored_cpus >= cpus {
		cpus = 1
	} else {
		cpus = cpus - ignored_cpus
	}

	// Print the number of CPUs
	println(cpus)

	// Quit
	exit(0)
}
