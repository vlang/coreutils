import os

fn setup_process_group(p os.Process, foreground bool) {
	// Fallback
}

fn terminate_process(p os.Process, sig_num int, process_group bool) {
	// Fallback: try to kill the process
	p.signal_kill()
}
