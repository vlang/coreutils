import os
import common

fn copy_file_progress(src string, dst string, mut bar common.ProgressBar) {
	// `in` is a keyword in V, so the handle is named src_f.
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

fn copy_dir_progress(src string, dst string, mut bar common.ProgressBar) {
	os.mkdir(dst) or {}
	entries := os.ls(src) or { [] }
	for entry in entries {
		child_src := os.join_path(src, entry)
		child_dst := os.join_path(dst, entry)
		if os.is_dir(child_src) {
			copy_dir_progress(child_src, child_dst, mut bar)
		} else {
			copy_file_progress(child_src, child_dst, mut bar)
		}
	}
}
