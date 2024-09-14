import os

fn test_help() {
	result := os.execute_or_panic('${os.quoted_path(@VEXE)} run . -h')
	assert result.exit_code == 0
	assert result.output.contains('a modified environment')
}

fn test_same_env() {
	result := os.execute_or_panic('${os.quoted_path(@VEXE)} run . -0')
	assert result.exit_code == 0

	env := os.execute_or_panic('env -0')
	assert env.exit_code == 0
	assert env.output == result.output
}

fn test_same_unset() {
	result := os.execute_or_panic('${os.quoted_path(@VEXE)} run . -u PATH')
	assert result.exit_code == 0

	env := os.execute_or_panic('env -u PATH')
	assert env.exit_code == 0
	assert env.output == result.output
}
