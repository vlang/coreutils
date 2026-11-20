module main

import term.termios

// Windows has no termios.h, so there is no terminal to drive: every helper
// reports failure and the caller prints the same 'Inappropriate ioctl for
// device' diagnostic GNU gives for a non-terminal. This file exists so the
// pure-V stty.v compiles on Windows alongside the nix implementation.

fn get_termios(fd int) ?termios.Termios {
	return none
}

fn set_termios(fd int, t termios.Termios) int {
	return -1
}

fn window_size(fd int) ?(int, int) {
	return none
}
