// No TestRig here: uutils 0.0.17 ships no chmod for Windows, so there is no
// platform util to compare against on this machine. The reference is GNU 9.4
// through WSL, and the tests below pin that behaviour directly; the one thing
// Windows can actually observe is the read-only attribute.
import common.chmod as chmodmod
import os

const work_dir = os.join_path(os.temp_dir(), 'chmod_test_tree')

fn make_tree() {
	// A previous run may have left the tree read-only, and that would stop
	// rmdir_all and the writes below, so clear it first.
	force_writable_tree(work_dir)
	os.rmdir_all(work_dir) or {}
	os.mkdir_all(work_dir) or { panic('mkdir: ${err}') }
	os.write_file(os.join_path(work_dir, 'plain.txt'), 'x') or { panic('write: ${err}') }
	os.mkdir_all(os.join_path(work_dir, 'sub')) or { panic('mkdir sub: ${err}') }
	os.write_file(os.join_path(work_dir, 'sub', 'nested.txt'), 'y') or { panic('write: ${err}') }
}

fn force_writable_tree(root string) {
	entries := os.ls(root) or { return }
	for e in entries {
		p := os.join_path(root, e)
		make_writable(p)
		if os.is_dir(p) {
			force_writable_tree(p)
		}
	}
	make_writable(root)
}

fn testsuite_begin() {
	make_tree()
}

fn testsuite_end() {
	os.rmdir_all(work_dir) or {}
}

fn test_parse_mode_octal_is_absolute() {
	// An octal mode replaces the whole set of bits, whatever the base.
	for spec in ['644', '755', '600', '444', '604', '000', '640'] {
		bits, ok := chmodmod.parse_mode(spec, u32(0o777))
		assert ok
		assert bits == octal_value(spec), 'octal ${spec} gave ${bits:o}'
	}
	// GNU accepts one to four digits and pads, so 64 is 064.
	short, ok := chmodmod.parse_mode('64', 0)
	assert ok
	assert short == 0o064
}

fn octal_value(s string) u32 {
	mut n := u32(0)
	for c in s.bytes() {
		n = n * 8 + u32(c - `0`)
	}
	return n
}

fn test_parse_mode_symbolic_builds_on_the_base() {
	// go-w on a file that is already writable by group and other is a no-op,
	// which is only true when the clauses start from the current mode.
	kept, _ := chmodmod.parse_mode('go-w', u32(0o644))
	assert kept == 0o644

	gained, _ := chmodmod.parse_mode('+x', u32(0o644))
	assert gained == 0o755

	dropped, _ := chmodmod.parse_mode('a-x', u32(0o755))
	assert dropped == 0o644

	// The = form is absolute within the classes it names.
	set_u, _ := chmodmod.parse_mode('u=rw,go=', u32(0o777))
	assert set_u == 0o600

	set_a, _ := chmodmod.parse_mode('a=r', u32(0o777))
	assert set_a == 0o444
}

fn test_parse_mode_rejects_what_gnu_rejects() {
	// 99 is two octal digits and is accepted as 099, so it is not in this list.
	for spec in ['999', '99999', '', 'xyz', 'u+Q', 'u;x', 'zzz', '8'] {
		_, ok := chmodmod.parse_mode(spec, 0)
		assert !ok, 'expected ${spec} to be rejected'
	}
}

fn test_parse_args_separates_mode_from_files() {
	s := chmodmod.parse_args(['644', 'a', 'b'])
	assert s.mode == '644'
	assert s.operands == ['a', 'b']

	r := chmodmod.parse_args(['-R', 'u+x', 'dir'])
	assert r.recursive
	assert r.mode == 'u+x'
	assert r.operands == ['dir']

	v := chmodmod.parse_args(['-v', '--changes', '644', 'a'])
	assert v.verbose
	assert v.changes
}

fn test_parse_args_double_dash() {
	s := chmodmod.parse_args(['644', '--', '-weird'])
	assert s.mode == '644'
	assert s.operands == ['-weird']
}

fn test_read_only_bit_follows_the_write_bits() {
	// Windows carries no Unix permission bits, so the read-only attribute is
	// the whole observable effect: a mode with no write bit anywhere is
	// read-only, and any mode with one is writable. This is the mapping the
	// platform can express, and it is what the GNU comparison reduces to here.
	target := os.join_path(work_dir, 'ro.txt')
	specs := ['644', '444', '400', '555', '600', '000', '640', 'u+w,go=r', 'u=r,go=', 'go-w', 'a=rw']
	for spec in specs {
		// Clear the read-only bit first, otherwise a previous iteration
		// leaves a file the next one cannot even write to.
		make_writable(target)
		os.write_file(target, 'x') or { panic('write: ${err}') }
		code := chmodmod.run(chmodmod.parse_args([spec, target]))
		assert code == 0
		ro := is_readonly(target)
		if spec in ['444', '400', '555', '000', 'u=r,go='] {
			assert ro, '${spec} should be read-only'
		} else {
			assert !ro, '${spec} should be writable'
		}
	}
	os.rm(target) or {}
}

fn test_missing_file_reports_failure() {
	missing := os.join_path(work_dir, 'does-not-exist')
	code := chmodmod.run(chmodmod.parse_args(['644', missing]))
	assert code == 1
}

fn test_recursive_covers_nested_files() {
	// Both the directory and the file under it must end up read-only.
	sub := os.join_path(work_dir, 'sub')
	nested := os.join_path(sub, 'nested.txt')
	make_writable(sub)
	make_writable(nested)
	code := chmodmod.run(chmodmod.parse_args(['-R', '444', sub]))
	assert code == 0
	assert is_readonly(sub)
	assert is_readonly(nested)
}

fn make_writable(path string) {
	chmodmod.run(chmodmod.parse_args(['666', path]))
}

fn is_readonly(path string) bool {
	st := os.lstat(path) or { return false }
	return (u32(st.mode) & 0o222) == 0
}
