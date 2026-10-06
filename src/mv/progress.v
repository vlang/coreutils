import os
import common

// move_file_progress copies the bytes with a bar and then removes the source, which
// is what mv does when the rename crosses a filesystem. A same-filesystem rename is
// instant and has nothing to show, so -progress takes the long path every time.
pub fn move_file_progress(src string, dst string, mut bar common.ProgressBar) {
	copy_bytes(src, dst, mut bar)
	os.rm(src) or {}
}

pub fn move_dir_progress(src string, dst string, mut bar common.ProgressBar) {
	copy_dir_bytes(src, dst, mut bar)
	remove_tree(src)
}

// remove_tree deletes a whole tree, files before the directories they sit in.
// rmdir only takes an empty directory, so the contents go first.
fn remove_tree(path string) {
	if !os.is_dir(path) {
		os.rm(path) or {}
		return
	}
	entries := os.ls(path) or { [] }
	for entry in entries {
		remove_tree(os.join_path(path, entry))
	}
	os.rmdir(path) or {}
}

fn copy_bytes(src string, dst string, mut bar common.ProgressBar) {
	mut src_f := os.open(src) or { return }
	defer {
		src_f.close()
	}
	mut dst_f := os.create(dst) or { return }
	defer {
		dst_f.close()
	}
	mut buf := []u8{len: 64 * 1024}
	for {
		n := src_f.read(mut buf) or { break }
		if n == 0 {
			break
		}
		dst_f.write(buf[..n]) or { break }
		bar.update(n)
	}
}

fn copy_dir_bytes(src string, dst string, mut bar common.ProgressBar) {
	os.mkdir(dst) or {}
	entries := os.ls(src) or { [] }
	for entry in entries {
		child_src := os.join_path(src, entry)
		child_dst := os.join_path(dst, entry)
		if os.is_dir(child_src) {
			copy_dir_bytes(child_src, child_dst, mut bar)
		} else {
			copy_bytes(child_src, child_dst, mut bar)
		}
	}
}
