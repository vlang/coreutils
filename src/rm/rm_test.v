test_rm_dir(rm RmCommand) ? {
	os.mkdir('dir1') ?
	os.mkdir('dir1/dir2') ?
	os.create('dir1/file1') ?
	os.create('dir1/dir2/file2') ?

	assert os.ls('dir1') ? == 2


	rm.rm_dir(rm)
}
