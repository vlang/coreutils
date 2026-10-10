// No TestRig here: uutils 0.0.17 ships no install for Windows, so there is no
// platform util to diff against. The reference is GNU 9.4 through WSL, and the
// four error diagnostics were compared byte-for-byte against it there; the mode
// mapping is pinned natively, because a Windows process cannot set Unix bits on
// a WSL path.
import common.install as installmod
import os

fn work_dir() string {
	return os.join_path(os.temp_dir(), 'install_test_tree')
}

fn source_path() string {
	return os.join_path(work_dir(), 'src.txt')
}

fn dest_path() string {
	return os.join_path(work_dir(), 'dest.txt')
}

fn testsuite_begin() {
	os.rmdir_all(work_dir()) or {}
	os.mkdir_all(work_dir()) or { panic('mkdir: ${err}') }
}

fn testsuite_end() {
	os.rmdir_all(work_dir()) or {}
}

fn make_source() {
	os.write_file(source_path(), 'hello') or { panic('write source: ${err}') }
}

fn run_install(args []string) int {
	return installmod.run(installmod.parse_args(args))
}

fn is_readonly(path string) bool {
	st := os.lstat(path) or { return false }
	return (u32(st.mode) & 0o222) == 0
}

fn set_writable(path string) {
	if !os.exists(path) {
		return
	}
	os.chmod(path, 0o666) or {}
}

fn test_copies_content_and_reports_success() {
	make_source()
	assert run_install(['-m', '644', source_path(), dest_path()]) == 0
	assert os.exists(dest_path())
	// The text form rather than read_file_array().bytestr(), which breaks
	// codegen in a _test.v build.
	assert os.read_file(dest_path()) or { '' } == 'hello'
}

fn test_parse_mode_accepts_octal_and_rejects_rest() {
	bits, ok := installmod.parse_mode('640')
	assert ok
	assert bits == 0o640

	bad, ok2 := installmod.parse_mode('999')
	assert !ok2
	assert bad == 0

	// Four digits are the set-id and sticky bits, and are accepted.
	four, ok3 := installmod.parse_mode('4755')
	assert ok3
	assert four == 0o4755

	two, ok4 := installmod.parse_mode('64')
	assert ok4
	assert two == 0o064
}

fn test_parse_args_defaults() {
	s := installmod.parse_args([])
	assert s.mode == '755'
	assert !s.mode_given
	assert !s.target_dir
	assert s.operands.len == 0
}

fn test_parse_args_mode_spellings() {
	// -m 640, -m640 and --mode=640 all mean the same thing.
	for spec in [['-m', '640'], ['-m640'], ['--mode=640'], ['--mode', '640']] {
		s := installmod.parse_args(spec)
		assert s.mode == '640', 'spec ${spec} gave ${s.mode}'
		assert s.mode_given
	}
}

fn test_parse_args_target_directory_is_not_a_source() {
	// This was a real bug: with -t the directory came back as a source operand
	// and the copy tried to stat the destination as an input.
	s := installmod.parse_args(['-t', 'dir', 'a', 'b'])
	assert s.target == 'dir'
	assert s.target_dir
	assert s.operands == ['a', 'b']

	long := installmod.parse_args(['--target-directory=dir', 'a'])
	assert long.target == 'dir'
	assert long.operands == ['a']
}

fn test_parse_args_flags() {
	s := installmod.parse_args(['-D', '-C', '-p', '-b', '-v', 'src', 'dst'])
	assert s.dir_flag
	assert s.no_clobber
	assert s.preserve
	assert s.backup
	assert s.verbose
	assert s.operands == ['src', 'dst']
}

fn test_parse_args_double_dash() {
	s := installmod.parse_args(['-m', '644', '--', '-weird.txt'])
	assert s.mode == '644'
	assert s.operands == ['-weird.txt']
}

fn test_mode_maps_to_the_read_only_bit() {
	// Windows stores no Unix permission bits, so the observable effect is the
	// read-only attribute: a mode with no write bit anywhere is read-only and
	// anything else is writable. This is what the platform can express.
	make_source()
	for spec in ['644', '640', '600', '755', '777', '666', '444', '400', '555', '000'] {
		set_writable(dest_path())
		assert run_install(['-m', spec, source_path(), dest_path()]) == 0
		ro := is_readonly(dest_path())
		if spec in ['444', '400', '555', '000'] {
			assert ro, '-m ${spec} should be read-only'
		} else {
			assert !ro, '-m ${spec} should be writable'
		}
	}
}

fn test_missing_source_reports_failure() {
	assert run_install(['-m', '644', os.join_path(work_dir(), 'nope.txt'), dest_path()]) == 1
}

fn test_directory_flag_creates_parents() {
	make_source()
	nested := os.join_path(work_dir(), 'a', 'b', 'c.txt')
	assert run_install(['-D', '-m', '700', source_path(), nested]) == 0
	assert os.exists(nested)
	assert os.is_dir(os.join_path(work_dir(), 'a', 'b'))
}
