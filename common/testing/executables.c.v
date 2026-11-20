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

// has_main_module reports whether dir holds a `module main` file, and so can
// be compiled to a standalone binary with `v -o exe dir`. Tools converted
// for the multicall are `module <tool>` instead, exposing `pub fn run`, so
// compiling their directory fails with "project must include a `main`
// module". Test files without a module clause do not count either way.
fn has_main_module(dir string) bool {
	files := os.ls(dir) or { return true }
	for f in files {
		if !f.ends_with('.v') {
			continue
		}
		content := os.read_file(os.join_path(dir, f)) or { continue }
		for line in content.split_into_lines() {
			t := line.trim_space()
			if t == '' || t.starts_with('//') {
				continue
			}
			if t.starts_with('module ') {
				if t == 'module main' || t.starts_with('module main ') || t.starts_with('module main\t') {
					return true
				}
				break
			}
			break
		}
	}
	return false
}

// prepare_executable compiles a coreutil executable,
// and returns its path. prepare_executable also ensures
// that the compiled executable will be deleted, when all
// the tests finish.
pub fn prepare_executable(tool_name string) string {
	tool_source_folder := os.join_path(@VMODROOT, 'src', tool_name)
	tool_executable_path := os.join_path(os.cache_dir(), '${tool_name}.exe')
	os.rm(tool_executable_path) or {}
	mut tool_source := tool_source_folder
	if !has_main_module(tool_source_folder) {
		// The tool was converted for the multicall: its directory has no
		// `fn main`, so `v -o exe src/<tool>` fails. Build the multicall
		// source instead, keeping the output named after the tool: dispatch
		// is by argv[0], so a binary called `<tool>.exe` runs `<tool>` with
		// no sub-command, and the tests keep invoking one path per tool.
		tool_source = os.join_path(@VMODROOT, 'src', 'multicall')
	}
	compilation_cmd := '${@VEXE} -cg -o ${tool_executable_path} ${tool_source}'
	$if debug {
		eprintln('>> compiling with: `${compilation_cmd}`')
	}
	res := os.exec_opt(split_args(compilation_cmd)) or { panic('could not run ${compilation_cmd}') }
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
