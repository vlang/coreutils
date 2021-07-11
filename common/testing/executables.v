module testing

import os

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

// prepare_executable compiles a coreutil executable,
// and returns its path. prepare_executable also ensures
// that the compiled executable will be deleted, when all
// the tests finish.
pub fn prepare_executable(tool_name string) string {
	tool_source_folder := os.join_path(@VMODROOT, 'src', tool_name)
	tool_executable_path := os.join_path(os.cache_dir(), '${tool_name}.exe')
	os.rm(tool_executable_path) or {}
	compilation_cmd := '${@VEXE} -cg -o $tool_executable_path $tool_source_folder'
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
