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
	fp.limit_free_args_to_at_least(1) ?

	// Get arguments
	print_help := fp.bool('help', 0, false, 'Print help')
	print_version := fp.bool('version', 0, false, 'Print version')
	all_flag := fp.bool('all', 0, false, 'Print the number of detected processor(s)')
	ignored_cpus := fp.int('ignore', 0, 0, 'Exclude N processing units if possible')

	// If the help / version is asked print the help and stop here
	if print_help || print_version {
		println(fp.usage())
		exit(0)
	}

	// Check if ignored CPUs is > 0
	if ignored_cpus < 0 {
		println('nproc: invalid number: \'$ignored_cpus\'')
		exit(1)
	}

	// Get number of CPUs
	mut cpus := runtime.nr_cpus()

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
