module testing

import os

pub struct CommandPair {
pub mut:
	original string // the system command (the GNU version)
	deputy   string // the V coreutils command (which should behave more or less the same)
}

// new_paired_command creates a new command pair, that is a structure,
// recording that a given command (the `original`) has been implemented
// in another executable (the `deputy`). The deputy should have the same
// behaviour more or less as the original.
pub fn new_paired_command(original string, deputy string) CommandPair {
	return CommandPair{
		original: original
		deputy: deputy
	}
}

// same_results - given some options, execute both the original
// and the deputy commands, and ensure that their results match
pub fn (p CommandPair) same_results(options string) {
	same_results('$p.original $options', '$p.deputy $options')
}

// command_fails executes a command, and ensures
// that its exit code is not 0 (i.e. the command failed)
// It also returns the actual result of the execution,
// so that you can inspect it further for more details.
pub fn command_fails(cmd string) os.Result {
	res := os.execute(cmd)
	assert res.exit_code != 0
	return res
}

// same_results/2 executes the given commands, and ensures that
// their results are exactly the same, both for their exit codes,
// and for their output.
pub fn same_results(cmd1 string, cmd2 string) {
	mut cmd1_res := os.execute(cmd1)
	mut cmd2_res := os.execute(cmd2)
	$if trace_same_results ? {
		eprintln('------------------------------------')
		eprintln('>> same_results cmd1: $cmd1')
		eprintln('>> same_results cmd2: $cmd2')
		eprintln('                cmd1_res.output.len: $cmd1_res.output.len | $cmd1_res.output')
		eprintln('                cmd2_res.output.len: $cmd2_res.output.len | $cmd2_res.output')
	}
	assert cmd1_res.exit_code == cmd2_res.exit_code
	assert cmd1_res.output == cmd2_res.output
}

// prepare_executable compiles a coreutil executable,
// and returns its path. prepare_executable also ensures
// that the compiled executable will be deleted, when all
// the tests finish.
pub fn prepare_executable(tool_name string) string {
	tool_source_folder := os.join_path(@VMODROOT, 'src', tool_name)
	tool_executable_path := os.join_path(os.cache_dir(), '${tool_name}.exe')
	os.rm(tool_executable_path) or {}
	vexe := @VEXE
	compilation_cmd := '$vexe -cg -o $tool_executable_path $tool_source_folder'
	res := os.execute(compilation_cmd)
	if res.exit_code != 0 {
		eprintln('Tool $tool_name could not be compiled.')
		eprintln('Compilation command:\n$compilation_cmd')
		exit(1)
	}
	if !os.exists(tool_executable_path) {
		eprintln('Tool $tool_name was compiled, but $tool_executable_path does not exist.')
		exit(2)
	}
	mut executables := unsafe { testing.prepared_executables }
	executables.paths << tool_executable_path
	return tool_executable_path
}

const prepared_executables = &PreparedExecutables{}

struct PreparedExecutables {
mut:
	paths []string
}

fn init() {
	C.atexit(fn () {
		for p in testing.prepared_executables.paths {
			os.rm(p) or {}
		}
	})
}

pub fn (p CommandPair) ensure_help_and_version_options_work() {
	// For now, assume that the original has --version and --help and
	// that they already work correctly.
	// assert os.execute('$p.original --help').exit_code == 0
	// assert os.execute('$p.original --version').exit_code == 0
	assert os.execute('$p.deputy --help').exit_code == 0
	assert os.execute('$p.deputy --version').exit_code == 0
}
