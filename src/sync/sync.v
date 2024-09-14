import common
import os

const app = common.CoreutilInfo{
	name:        'sync'
	description: 'Synchronize cached writes to persistent storage'
}

// TODO: Make a Windows version using C.FlushFileBuffers()

// Settings for Utility: sync
struct Settings {
mut:
	data         bool
	file_system  bool
	target_files []string
}

fn args() Settings {
	mut fp := app.make_flag_parser(os.args)
	mut st := Settings{}
	st.data = fp.bool('data', `d`, false, 'sync only file data, no unneeded metadata')
	st.file_system = fp.bool('file-system', `f`, false, 'sync the file systems that contain the files')
	st.target_files = fp.remaining_parameters()
	if st.data && st.file_system {
		app.quit(message: 'cannot specify both --data and --file-system')
	}
	if st.target_files.len == 0 {
		if st.data {
			app.quit(message: '--data needs at least one argument')
		}
		st.target_files << '.'
		st.file_system = true
	}
	return st
}

fn sync(settings Settings) {
	for path in settings.target_files {
		// open file read-only and non-blocking
		// TODO: there is more sophisticated handling in the
		// GNU coreutil version with O_WRONLY attempts
		mut f := os.open_file(path, 'rn') or {
			app.quit(message: "error opening '${path}': ${err.msg()}")
		}
		defer {
			f.close()
		}
		if settings.data {
			do_fdatasync(f.fd) or { app.quit(message: err.msg()) }
		} else if settings.file_system {
			do_sync(f.fd) or { app.quit(message: err.msg()) }
		} else {
			do_fsync(f.fd) or { app.quit(message: err.msg()) }
		}
	}
}

fn main() {
	sync(args())
}
