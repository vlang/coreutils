module testing

import os

// TestRig contains the relevant scaffolding for tests to avoid boilerplate in
// the individual <util>_test.v files
pub struct TestRig {
pub:
	util                  string
	platform_util         string
	executable_under_test string
	temp_dir              string
	cmd                   CommandPair
	is_supported_platform bool
}

pub struct TestRigConfig {
pub:
	util                  string
	is_supported_platform bool = true
}

pub fn prepare_rig(config TestRigConfig) TestRig {
	local_util_name := $if !windows {
		config.util
	} $else {
		'coreutils'
	}

	local_util := os.find_abs_path_of_executable(local_util_name) or {
		panic("Local platform util '${local_util_name}' not found!")
	}
	platform_util := if local_util_name == 'coreutils' {
		'${local_util} ${config.util}'
	} else {
		local_util
	}

	exec_under_test := if config.is_supported_platform {
		prepare_executable(config.util)
	} else {
		''
	}
	temp_dir := os.join_path(temp_folder, config.util)
	os.mkdir(temp_dir) or { panic('Unable to make test directory: ${temp_dir}') }
	os.chdir(temp_dir) or { panic('Unable to set working directory: ${temp_dir}') }
	rig := TestRig{
		util: config.util
		platform_util: platform_util
		cmd: new_paired_command(platform_util, exec_under_test)
		executable_under_test: exec_under_test
		temp_dir: temp_dir
		is_supported_platform: config.is_supported_platform
	}
	C.atexit(rig.clean_up)
	return rig
}

pub fn (rig TestRig) call_for_test(args string) os.Result {
	res := os.execute('${rig.executable_under_test} ${args}')
	assert res.exit_code == 0
	return res
}

pub fn (rig TestRig) clean_up() {
	if os.is_dir(rig.temp_dir) {
		os.rmdir_all(rig.temp_dir) or {}
	}
}
