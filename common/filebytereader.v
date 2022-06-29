module common

import os

pub const eof = -1

const read_buf_size = 256

pub struct FileByteReader {
	file os.File
	buf_size int
mut:
	reached_end  bool
	returned_eof  bool
	buf_index    int
	buf_data_len int
	cursor       u64
	buf          []u8
}

pub fn new_file_byte_reader(fp os.File) FileByteReader {
	return FileByteReader{
		file: fp
		buf_size: common.read_buf_size
		buf: []u8{len: common.read_buf_size}
	}
}

pub fn (mut r FileByteReader) has_next() bool {
	if r.reached_end && r.returned_eof {
		return false
	}

	if r.buf_index == r.buf_data_len {
		r.buf_index = 0
		r.buf_data_len = r.file.read_bytes_into(r.cursor, mut r.buf) or { 0 }
		r.cursor += u64(r.buf_data_len)
	}

	if r.buf_data_len == 0 {
		r.reached_end = true
		return true
	}

	return r.buf_index < r.buf_data_len
}

pub fn (mut r FileByteReader) next() int {
	if r.buf_index + 1 > r.buf_data_len {
		r.returned_eof = true
		return common.eof
	}
	c := r.buf[r.buf_index]
	r.buf_index++
	return int(c)
}
