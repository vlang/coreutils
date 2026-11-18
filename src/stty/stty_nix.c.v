module main

import term.termios

#include <termios.h>
#include <sys/ioctl.h>

// All C traffic for stty lives in this file (with a no-termios stub in
// stty_windows.c.v), because the compiler no longer permits any `C.`
// reference in a pure .v file. stty.v and stty_nix_test.v stay pure V: they
// only see vlib's `termios.Termios` and talk to the terminal through the
// three helpers below.
//
// `struct C.termios` itself is declared by vlib/term/termios against the real
// header, so it is not redeclared here. Only the window size needs a local
// declaration: vlib has no winsize type.

struct C.winsize {
	ws_row    u16
	ws_col    u16
	ws_xpixel u16
	ws_ypixel u16
}

fn get_termios(fd int) ?termios.Termios {
	mut t := termios.Termios{}
	if termios.tcgetattr(fd, mut t) != 0 {
		return none
	}
	return t
}

fn set_termios(fd int, t termios.Termios) int {
	mut attrs := t
	return termios.tcsetattr(fd, 0, mut attrs)
}

fn window_size(fd int) ?(int, int) {
	mut ws := C.winsize{}
	// TIOCGWINSZ differs per kernel (0x5413 on Linux), so take it from the
	// header instead of hardcoding the Linux value.
	if termios.ioctl(fd, u64(C.TIOCGWINSZ), voidptr(&ws)) != 0 {
		return none
	}
	return int(ws.ws_row), int(ws.ws_col)
}
