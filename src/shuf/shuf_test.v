import os
import common.testing

const shuf = testing.prepare_executable('shuf')

fn test_echo() {
	res := os.execute('$shuf -e aa bb')
	assert (res.output == 'aa\nbb\n') || (res.output == 'bb\naa\n')
}

fn test_file() {
	filename := './test.txt'
	hello := 'hello\nworld!'
	mut file := os.open_file(filename, 'w+', 0o666) or { panic(err) }
	file.write_string(hello) or { panic(err) }
	file.close()

	res := os.execute('$shuf test.txt')
	assert (res.output == 'hello\nworld!\n') || (res.output == 'world!\nhello\n')
}

fn test_zero_terminated_echo() {
	res := os.execute('$shuf -z -e aa bb')
	assert (res.output == 'aabb') || (res.output == 'bbaa')
}

fn test_zero_terminated_file() {
	filename := './test.txt'
	hello := 'hello\nworld!'
	mut file := os.open_file(filename, 'w+', 0o666) or { panic(err) }
	file.write_string(hello) or { panic(err) }
	file.close()

	res := os.execute('$shuf -z test.txt')
	assert res.output == 'hello\nworld!'
}

fn test_head_count() {
	res := os.execute('$shuf -n 5 -i 1-10')
	println(res.output.split('\n'))
	assert res.output.split('\n').len - 1 == 5
}

fn test_input_range() {
	res := os.execute('$shuf -i 1-10')
	assert res.output.split('\n').len - 1 == 10
}

fn test_random_source() {
	filename := './test.txt'
	hello := 'hello\nworld!'
	mut file := os.open_file(filename, 'w+', 0o666) or { panic(err) }
	file.write_string(hello) or { panic(err) }
	file.close()

	res := os.execute('$shuf -i 1-5 --random-source test.txt')
	assert res.output == '1\n4\n5\n2\n3\n'
}

fn test_unknown_option() ? {
	res := os.execute('$shuf -x')
	assert res.exit_code == 1
}
