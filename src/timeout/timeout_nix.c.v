import os

@[c: 'kill']
fn C.kill(pid int, sig int) int

@[c: 'setpgid']
fn C.setpgid(pid int, pgid int) int

fn setup_process_group(p os.Process, foreground bool) {
	if !foreground {
		C.setpgid(p.pid, 0)
	}
}

// All three platform variants take `mut p`, so the caller in timeout.v can pass
// `mut &p` unconditionally. Passing this one by value made the compiler insert an
// automatic reference and then reject that as deprecated.
fn terminate_process(mut p &os.Process, sig_num int, process_group bool) {
	pid := if process_group { -p.pid } else { p.pid }
	C.kill(pid, sig_num)
}
