module mv

fn test_valid_yes() {
	// assert 1==2
	assert valid_yes('y')
	assert valid_yes('Y')
	assert valid_yes('Yes')
	assert valid_yes('yes')
	assert valid_yes('YE')
	assert valid_yes('YASS')
	assert valid_yes('YES!!!!')

	assert !valid_yes('NO')
	assert !valid_yes('n')
	assert !valid_yes('no.. yes')
}
