module common

import os

const read_buf_size = 256

pub struct FileByteReader {
	file_ptr os.File
	buf_size int
mut:
	buf_index int
	buf_data_len int
	cursor u64
	buf []u8
}

pub fn new_file_byte_reader(fp os.File) FileByteReader {
	return FileByteReader{
		file_ptr: fp
		buf_size: read_buf_size
		buf: []u8{len: read_buf_size}
	}
}

pub fn (mut r FileByteReader) has_next() bool {
	if r.buf_index == r.buf_data_len {
		r.buf_index = 0
		r.buf_data_len = r.file_ptr.read_bytes_into(r.cursor, mut r.buf) or { 0 }
		r.cursor += u64(r.buf_data_len)
	}

	return r.buf_index < r.buf_data_len
}

pub fn (mut r FileByteReader) next() ?u8 {
	if r.buf_index + 1 > r.buf_data_len {
		return error('reached end of data $r.buf_data_len[$r.buf_index]')
	}
	c := r.buf[r.buf_index]
	r.buf_index++
	return c
}
