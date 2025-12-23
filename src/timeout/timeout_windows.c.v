import os

fn setup_process_group(p os.Process, foreground bool) {
	// Windows doesn't support process groups
}

fn terminate_process(p os.Process, sig_num int, process_group bool) {
	// TERM, Windows doesn't seem to support signals like Unixes does
	if sig_num == 15 {
		p.signal_term()
	} else {
		p.signal_kill()
	}
}
