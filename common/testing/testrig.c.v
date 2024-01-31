module testing

import os

pub fn prepare_rig(config TestRigConfig) TestRig {
	call_util := $if !windows {
		config.util
	} $else {
		'coreutils'
	}

	platform_util_path := os.find_abs_path_of_executable(call_util) or {
		panic("Local platform util '${call_util}' not found!")
	}

	platform_util := if call_util == 'coreutils' {
		'${call_util} ${config.util}'
	} else {
		call_util
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
		platform_util_path: platform_util_path
		cmd: new_paired_command(platform_util, exec_under_test)
		executable_under_test: exec_under_test
		temp_dir: temp_dir
		is_supported_platform: config.is_supported_platform
	}
	C.atexit(rig.clean_up)
	return rig
}
