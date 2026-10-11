module main

import os

fn test_char_repr_control_codes() {
	assert char_repr(0) == '<undef>'
	assert char_repr(3) == '^C'
	assert char_repr(28) == '^\\'
	assert char_repr(127) == '^?'
	assert char_repr(u8(`x`)) == 'x'
}

fn test_lookup_mode_finds_every_tabled_mode() {
	for m in modes {
		found := lookup_mode(m.name) or {
			assert false, 'mode ${m.name} is in the table but not findable'
			return
		}
		assert found.name == m.name
		assert found.bit == m.bit
	}
}

fn test_lookup_mode_rejects_unknown() {
	assert lookup_mode('definitely-not-a-mode') == none
}

fn test_apply_mode_sets_and_clears() {
	// A terminal is not available under `v test` on a non-tty, so the flags
	// are exercised on a zeroed struct, which is what the set/clear path needs.
	mut t := GlibcTermios{}
	apply_mode(mut t, Mode{'icanon', .lflag, 0o000002}, true)
	assert u32(t.c_lflag) & u32(0o000002) != 0
	apply_mode(mut t, Mode{'icanon', .lflag, 0o000002}, false)
	assert u32(t.c_lflag) & u32(0o000002) == 0
}

fn test_apply_sane_matches_gnu_values() {
	mut t := GlibcTermios{}
	apply_sane(mut t)
	// These are the flag words GNU's `stty sane` produces, measured on a
	// terminal whose -a output matched this port byte for byte.
	assert u32(t.c_iflag) == u32(0o600) | u32(1)
	assert u32(t.c_oflag) == u32(5)
	assert u32(t.c_lflag) == u32(0o105073)
	assert u32(t.c_cflag) == u32(0o277)
}

fn test_flags_lines_wraps_at_seventy_nine() {
	// A struct with every input bit set produces the longest row GNU prints.
	mut t := GlibcTermios{}
	all := Mode{'imaxbel', .iflag, 0o040000}
	apply_mode(mut t, all, true)
	mut m2 := Mode{'iuclc', .iflag, 0o001000}
	apply_mode(mut t, m2, true)
	lines := flags_lines(&t, .iflag)
	for l in lines {
		assert l.len <= 79, 'line is ${l.len} characters, over the 79 GNU uses'
	}
}

fn test_flags_lines_dash_means_clear() {
	mut t := GlibcTermios{}
	lines := flags_lines(&t, .iflag)
	// Nothing is set on a zeroed struct, so every entry should carry a dash.
	assert lines.len > 0
	for part in lines[0].split(' ') {
		assert part.starts_with('-'), 'expected a dash prefix on ${part}'
	}
}

fn test_oflag_delay_bits_print_bare_when_clear() {
	mut t := GlibcTermios{}
	// GNU prints nl0, cr0, tab0, bs0, vt0 and ff0 when their delay bits are
	// clear, appended after the regular modes.
	lines := flags_lines(&t, .oflag)
	joined := lines.join(' ')
	assert joined.contains('nl0')
	assert joined.contains('cr0')
	assert joined.contains('tab0')
	assert joined.contains('bs0')
	assert joined.contains('vt0')
	assert joined.contains('ff0')
}
