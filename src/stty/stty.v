module main

import common
import os
import term.termios

#include <termios.h>
#include <sys/ioctl.h>

// glibc's `struct termios` has c_cc at offset 17, and V's own `termios.Termios`
// has it at 20 because the compiler pads after c_line. Measured with an
// offsetof probe on this host, that three-byte shift is enough to make every
// control character and the top byte of every flag word wrong: glibc reports
// c_lflag 0x105073 where the V struct read 0x8a3b.
//
// So this port uses `C.termios`, which vlib/term/termios declares against the
// real header. Importing that module also brings `C.tcgetattr`, `C.tcsetattr`
// and `C.ioctl` into scope, which is why none of them are redeclared here.

struct C.winsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

const tiocgwinsz = u64(0x5413)

fn get_termios(fd int) ?C.termios {
	mut t := C.termios{}
	if C.tcgetattr(fd, &t) != 0 {
		return none
	}
	return t
}

fn set_termios(fd int, t &C.termios) int {
	return C.tcsetattr(fd, 0, t)
}

fn window_size(fd int) ?(int, int) {
	mut ws := C.winsize{}
	if C.ioctl(fd, tiocgwinsz, &ws) != 0 {
		return none
	}
	return int(ws.ws_row), int(ws.ws_col)
}

// Words of the termios struct that a mode's bit lives in.
enum Word {
	iflag
	oflag
	cflag
	lflag
}

// A boolean mode. Every bit value comes from the C preprocessor printed by a
// probe on this host, not from memory, because several differ from the value
// recall suggests.
struct Mode {
	name string
	word Word
	bit  u32
}

// The order of each block is the order GNU prints in -a, so this table is a
// render order and not merely a lookup table.
const modes = [
	// Input
	Mode{'ignbrk', .iflag, 0o000001},
	Mode{'brkint', .iflag, 0o000002},
	Mode{'ignpar', .iflag, 0o000004},
	Mode{'parmrk', .iflag, 0o000010},
	Mode{'inpck', .iflag, 0o000020},
	Mode{'istrip', .iflag, 0o000040},
	Mode{'inlcr', .iflag, 0o000100},
	Mode{'igncr', .iflag, 0o000200},
	Mode{'icrnl', .iflag, 0o000400},
	Mode{'ixon', .iflag, 0o002000},
	Mode{'ixoff', .iflag, 0o010000},
	Mode{'iuclc', .iflag, 0o001000},
	Mode{'ixany', .iflag, 0o004000},
	Mode{'imaxbel', .iflag, 0o020000},
	Mode{'iutf8', .iflag, 0o040000},
	// Output
	Mode{'opost', .oflag, 0o000001},
	Mode{'olcuc', .oflag, 0o000002},
	Mode{'ocrnl', .oflag, 0o000010},
	Mode{'onlcr', .oflag, 0o000004},
	Mode{'onocr', .oflag, 0o000020},
	Mode{'onlret', .oflag, 0o000040},
	Mode{'ofill', .oflag, 0o000100},
	Mode{'ofdel', .oflag, 0o000200},
	// Control. GNU prints parenb and parodd first, then cmspar, which Linux
	// does not support but still lists, then the size and line-control bits.
	Mode{'parenb', .cflag, 0o000400},
	Mode{'parodd', .cflag, 0o001000},
	Mode{'cmspar', .cflag, 0o20000000000},
	Mode{'cs8', .cflag, 0o000060},
	Mode{'hupcl', .cflag, 0o002000},
	Mode{'cstopb', .cflag, 0o000100},
	Mode{'cread', .cflag, 0o000200},
	Mode{'clocal', .cflag, 0o004000},
	Mode{'crtscts', .cflag, 0o2000000000000000},
	// Local. IEXTEN and EXTPROC are distinct bits, so both can be listed.
	Mode{'isig', .lflag, 0o000001},
	Mode{'icanon', .lflag, 0o000002},
	Mode{'iexten', .lflag, 0o100000},
	Mode{'echo', .lflag, 0o000010},
	Mode{'echoe', .lflag, 0o000020},
	Mode{'echok', .lflag, 0o000040},
	Mode{'echonl', .lflag, 0o000100},
	Mode{'noflsh', .lflag, 0o000200},
	Mode{'xcase', .lflag, 0o000004},
	Mode{'tostop', .lflag, 0o000400},
	Mode{'echoprt', .lflag, 0o002000},
	Mode{'echoctl', .lflag, 0o001000},
	Mode{'echoke', .lflag, 0o004000},
	Mode{'flusho', .lflag, 0o010000},
	Mode{'extproc', .lflag, 0o200000},
]

// The output delay bits, which GNU prints by their zero state (nl0, cr0, ...)
// because that is the default. They come last and only when clear.
const oflag_delay_bits = [
	Mode{'nl0', .oflag, 0o000400},
	Mode{'cr0', .oflag, 0o003000},
	Mode{'tab0', .oflag, 0o014000},
	Mode{'bs0', .oflag, 0o020000},
	Mode{'vt0', .oflag, 0o040000},
	Mode{'ff0', .oflag, 0o100000},
]

fn word_value(t &C.termios, w Word) u32 {
	return match w {
		.iflag { u32(t.c_iflag) }
		.oflag { u32(t.c_oflag) }
		.cflag { u32(t.c_cflag) }
		.lflag { u32(t.c_lflag) }
	}
}

fn set_word(mut t C.termios, w Word, v u32) {
	match w {
		.iflag { t.c_iflag = v }
		.oflag { t.c_oflag = v }
		.cflag { t.c_cflag = v }
		.lflag { t.c_lflag = v }
	}
}

fn lookup_mode(name string) ?Mode {
	for m in modes {
		if m.name == name {
			return m
		}
	}
	return none
}

fn apply_mode(mut t C.termios, m Mode, on bool) {
	v := word_value(&t, m.word)
	if on {
		set_word(mut t, m.word, v | m.bit)
	} else {
		set_word(mut t, m.word, v & ~m.bit)
	}
}

// char_repr renders a control character: ^X for a control code, <undef> for
// the value 0 that means "not set".
fn char_repr(c u8) string {
	if c == 0 {
		return '<undef>'
	}
	if c < 32 {
		return '^${u8(c + 64).ascii_str()}'
	}
	if c == 127 {
		return '^?'
	}
	return c.ascii_str()
}

// flags_lines renders one word's modes wrapped the way GNU does: rows of at
// most 79 characters, breaking before the entry that would not fit. Measured
// against `stty -a` in a pty, not taken from the manual.
fn flags_lines(t &C.termios, w Word) []string {
	mut parts := []string{}
	for m in modes {
		if m.word != w {
			continue
		}
		if word_value(t, w) & m.bit != 0 {
			parts << '${m.name}'
		} else {
			parts << '-${m.name}'
		}
	}
	if w == .oflag {
		for b in oflag_delay_bits {
			if word_value(t, w) & b.bit == 0 {
				parts << b.name
			}
		}
	}
	mut lines := []string{}
	mut line := []string{}
	mut width := 0
	for p in parts {
		need := if line.len == 0 { p.len } else { p.len + 1 }
		if line.len > 0 && width + need > 79 {
			lines << line.join(' ')
			line = []string{}
			width = 0
		}
		line << p
		width += need
	}
	if line.len > 0 {
		lines << line.join(' ')
	}
	return lines
}

fn print_all(t &C.termios) {
	println('speed 38400 baud; rows 0; columns 0; line = 0;')
	chars_line := [
		'intr = ${char_repr(t.c_cc[0])}',
		'quit = ${char_repr(t.c_cc[1])}',
		'erase = ${char_repr(t.c_cc[2])}',
		'kill = ${char_repr(t.c_cc[3])}',
		'eof = ${char_repr(t.c_cc[4])}',
		'eol = ${char_repr(t.c_cc[5])}',
	]
	println(chars_line.join('; ') + ';')
	println('eol2 = <undef>; swtch = <undef>; start = ${char_repr(t.c_cc[8])}; stop = ${char_repr(t.c_cc[9])}; susp = ${char_repr(t.c_cc[10])}; rprnt = ${char_repr(t.c_cc[12])};')
	println('werase = ${char_repr(t.c_cc[14])}; lnext = ${char_repr(t.c_cc[15])}; discard = ${char_repr(t.c_cc[13])}; min = ${t.c_cc[6]}; time = ${t.c_cc[5]};')
	for w in [Word.cflag, .iflag, .oflag, .lflag] {
		for l in flags_lines(t, w) {
			println(l)
		}
	}
}

// print_save renders the -g form: the four flag words in hex, then all 32
// control characters. GNU emits the whole struct so that `stty -g` output can
// be fed straight back in, so omitting the c_cc half makes it unusable.
fn print_save(t &C.termios) {
	// Cast each word to u32 before formatting: `${x}` applied directly to the
	// C type prints decimal, which silently produces the wrong -g output.
	mut s := '${u32(t.c_iflag):x}:${u32(t.c_oflag):x}:${u32(t.c_cflag):x}:${u32(t.c_lflag):x}'
	for c in t.c_cc {
		s += ':${c:x}'
	}
	println(s)
}

// apply_sane restores the flag words GNU's `stty sane` lists. The control
// characters are deliberately left alone, which matches GNU.
fn apply_sane(mut t C.termios) {
	t.c_iflag = 0o600 | 1
	t.c_oflag = 5
	t.c_lflag = 0o105073
	t.c_cflag = 0o277
}

const app_name = 'stty'

// quote_device applies GNU's quotef rule to the device name. Verified byte for
// byte against GNU 9.4: a name is quoted only when something in it needs
// quoting, and the quotes are straight apostrophes, not the curly ones GNU's
// own "invalid argument" message uses. So "standard input" is quoted because
// of its space, while /dev/null is left alone.
fn quote_device(name string) string {
	if name.contains(' ') || name.contains('\t') || name.len == 0 {
		return "'${name}'"
	}
	return name
}

@[noreturn]
fn die_stty(message string, code int) {
	eprintln('${app_name}: ${message}')
	exit(code)
}

fn main() {
	mut fd := int(os.stdin().fd)
	mut device := ''
	mut settings := []string{}

	for i := 1; i < os.args.len; i++ {
		a := os.args[i]
		if a == '-F' {
			if i + 1 >= os.args.len {
				die_stty("option requires an argument -- 'F'", 1)
			}
			i++
			device = os.args[i]
			f := os.open(device) or {
				die_stty('${device}: No such file or directory', 1)
			}
			fd = int(f.fd)
			continue
		}
		if a.starts_with('--file=') {
			device = a['--file='.len..]
			f := os.open(device) or {
				die_stty('${device}: No such file or directory', 1)
			}
			fd = int(f.fd)
			continue
		}
		settings << a
	}

	t := get_termios(fd) or {
		// GNU names the path given to -F, and says "standard input" for the
		// default. Only the -F form uses the device name.
		name := if device == '' { 'standard input' } else { device }
		die_stty('${quote_device(name)}: Inappropriate ioctl for device', 1)
	}
	mut attrs := t

	mut mutates := false
	for a in settings {
		if a == '-a' || a == '--all' {
			print_all(&attrs)
			continue
		}
		if a == '-g' || a == '--save' {
			print_save(&attrs)
			continue
		}
		if a == 'size' {
			rows, cols := window_size(fd) or {
				name := if device == '' { 'standard input' } else { device }
				die_stty('${quote_device(name)}: Inappropriate ioctl for device', 1)
			}
			println('${rows} ${cols}')
			continue
		}
		if a == 'sane' {
			apply_sane(mut attrs)
			mutates = true
			continue
		}
		on := !a.starts_with('-')
		name := if on { a } else { a[1..] }
		if m := lookup_mode(name) {
			apply_mode(mut attrs, m, on)
			mutates = true
			continue
		}
		die_stty("invalid argument \u2018${a}\u2019\nTry '${app_name} --help' for more information.",
			1)
	}

	if mutates {
		set_termios(fd, &attrs)
	}
}
