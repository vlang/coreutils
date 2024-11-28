import common
import flag
import os

@[name: 'shred']
@[version: '0.1']
struct Config {
	force         bool   @[short: f; xdoc: 'change permissions to allow writing if necessary']
	iterations    int = 3    @[short: n; xdoc: 'overwrite N times instead of the default (3)']
	random_source string @[xdoc: 'get random bytes from <string>']
	size          string @[short: s; xdoc: 'shred this many bytes (suffixes like K, M, G accepted)\n']
	rm            bool   @[only: u; xdoc: 'deallocate and remove file after overwriting']
	remove_how    string @[long: remove; xdoc: 'like -u but give control on <string> to delete;  See below']
	verbose       bool   @[short: v; xdoc: 'show progress']
	exact         bool   @[short: x; xdoc: 'do not round file sizes up to the next full block; this is the default for non-regular files']
	zero          bool   @[short: z; xdoc: 'add a final overwrite with zeros to hide shredding']
	show_help     bool   @[long: help; short: h; xdoc: 'show this help']
	show_version  bool   @[long: 'version'; xdoc: 'show version and exit']
}

fn get_args() (Config, []string) {
	config, files := flag.to_struct[Config](os.args, skip: 1) or { panic(err) }

	if config.show_help {
		doc := flag.to_doc[Config](
			description: 'Usage: shred [OPTION]... FILE...\n' +
				'Overwrite the specified FILE(s) repeatedly, in order to make it harder\n' +
				'for even very expensive hardware probing to recover the data.'
			footer:
				'\nDelete FILE(s) if --remove (-u) is specified. The default is not to remove\n' +
				'the files because it is common to operate on device files like /dev/hda,\n' +
				'and those files usually should not be removed.\n\n' +
				'The --remove <string> parameter indicates how to remove a directory entry:\n' +
				"  'unlink'   => use a standard unlink call.\n" +
				"  'wipe'     => also first obfuscate bytes in the name.\n" +
				"  'wipesync' => also sync each obfuscated byte to the device.\n" +
				"The default mode is 'wipesync', but note it can be expensive.\n\n" +
				'CAUTION: shred assumes the file system and hardware overwrite data in place.\n' +
				'Although this is common, many platforms operate otherwise. Also, backups\n' +
				'and mirrors may contain unremovable copies that will let a shredded file\n' +
				'be recovered later.\n' + common.coreutils_footer()
		) or { panic(err) }
		println(doc)
		exit(0)
	}

	if files.len > 0 && files.any(it.starts_with('-')) {
		eexit('The following flags could not be mapped to any fields: ${files.filter(it.starts_with('-'))}')
	}

	if files.filter(!it.starts_with('-')).len == 0 {
		eexit('missing file operand')
	}

	if config.iterations <= 0 {
		eexit('interations must be greater than zero')
	}

	return config, files
}

@[noreturn]
fn eexit(msg string) {
	eprintln(msg)
	exit(1)
}
