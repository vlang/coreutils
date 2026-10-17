import os

fn setup_process_group(p os.Process, foreground bool) {
	// Windows doesn't support process groups
}

// A pointer, because signalling a process changes it. Passing it by value, as the
// nix version can, made the compiler reference it for us and then reject that as
// deprecated automatic referencing.
fn terminate_process(mut p &os.Process, sig_num int, process_group bool) {
	// TERM, Windows doesn't seem to support signals like Unixes does
	if sig_num == 15 {
		p.signal_term()
	} else {
		p.signal_kill()
	}
}
