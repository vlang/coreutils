// The chroot(2) and chdir(2) bindings live here so the pure .v file never
// calls C directly, which current V rejects with 'C code will not be allowed
// in pure .v files'. This is the same boundary src/nohup/nohup.c.v draws
// around C.dup2.
fn C.chroot(path &char) int
fn C.chdir(path &char) int

// change_root enters the new root directory, returning 0 on success.
pub fn change_root(path string) int {
	return C.chroot(&char(path.str))
}

// enter_root_dir moves to the root of the new filesystem, which GNU does
// after the chroot unless --skip-chdir was given.
pub fn enter_root_dir() int {
	return C.chdir(&char(`/`.str))
}
