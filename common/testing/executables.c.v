module testing

import os

const prepared_executables = &PreparedExecutables{}

struct PreparedExecutables {
mut:
	paths []string
}

// temp_folder - all temporary files for the tests should be stored here.
// The folder `testing.temp_folder` will be removed automatically after all the tests are run.
pub const temp_folder = os.join_path(os.temp_dir(), 'v', 'coreutils', os.getpid().str())

fn init() {
	os.mkdir_all(temp_folder) or { panic(err) }
	C.atexit(fn () {
		for p in prepared_executables.paths {
			os.rm(p) or {}
		}
		os.rmdir_all(temp_folder) or {}
	})
}

// prepare_executable compiles a coreutil executable,
// and returns its path. prepare_executable also ensures
// that the compiled executable will be deleted, when all
// the tests finish.
pub fn prepare_executable(tool_name string) string {
	tool_source_folder := os.join_path(@VMODROOT, 'src', tool_name)
	tool_executable_path := os.join_path(os.cache_dir(), '${tool_name}.exe')
	os.rm(tool_executable_path) or {}
	compilation_cmd := '${@VEXE} -cg -o ${tool_executable_path} ${tool_source_folder}'
	$if debug {
		eprintln('>> compiling with: `${compilation_cmd}`')
	}
	res := os.execute(compilation_cmd)
	if res.exit_code != 0 {
		eprintln('Tool ${tool_name} could not be compiled.')
		eprintln('Compilation command:\n${compilation_cmd}')
		exit(1)
	}
	if !os.exists(tool_executable_path) {
		eprintln('Tool ${tool_name} was compiled, but ${tool_executable_path} does not exist.')
		exit(2)
	}
	mut executables := unsafe { prepared_executables }
	executables.paths << tool_executable_path
	return tool_executable_path
}
