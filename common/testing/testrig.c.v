module testing

pub fn wire_clean_up_at_exit(rig TestRig) {
	C.atexit(rig.clean_up)
}
