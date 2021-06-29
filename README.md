# coreutils in V

This repository contains programs equivalent to GNU [coreutils](https://www.gnu.org/software/coreutils/), written in the [V language](https://vlang.io).

## Layout

Each command has it's own separate subdirectory, in case the implementor wishes to create multiple `.v` files to implement a command.

## Building

Running `make` or `v run build.vsh` will build all the programs in `bin/`.

## Contributing

Contributions are welcome!

Please only contribute versions of the original utilities written in V.  Contributions written in other langauges will likely be rejected.

## Completed (2/109)

| ?   | cmd       | description                                      |
| --- | --------- | ------------------------------------------------ |
| X   | **[**     | Alternate form of `test`                         |
| X   | arch      | Print machine hardware name                      |
| X   | b2sum     | Print or check BLAKE2 digests                    |
| X   | base32    | Transform data into printable data               |
| X   | base64    | Transform data into printable data               |
| X   | basename  | Strip directory and suffix from a file name      |
| X   | basenc    | Transform data into printable data               |
| X   | cat       | Concatenate and write files                      |
| X   | chcon     | Change SELinux context of file                   |
| X   | chgrp     | Change group ownership                           |
| X   | chmod     | Change access permissions                        |
| X   | chown     | Change file owner and group                      |
| X   | chroot    | Run a command with a different root directory    |
| X   | cksum     | Print CRC checksum and byte counts               |
| X   | comm      | Compare two sorted files line by line            |
| X   | coreutils | Multi-call program                               |
| X   | cp        | Copy files and directories                       |
| X   | csplit    | Split a file into context-determined pieces      |
| X   | cut       | Print selected parts of lines                    |
| X   | date      | Print or set system date and time                |
| X   | dd        | Convert and copy a file                          |
| X   | df        | Report file system disk space usage              |
| X   | dir       | Briefly list directory contents                  |
| X   | dircolors | Color setup for ls                               |
| X   | dirname   | Strip last file name component                   |
| X   | du        | Estimate file space usage                        |
| X   | echo      | Print a line of text                             |
| X   | env       | Run a command in a modified environment          |
| X   | expand    | Convert tabs to spaces                           |
| X   | expr      | Evaluate expressions                             |
| X   | factor    | Print prime factors                              |
| V   | false     | Do nothing, unsuccessfully                       |
| X   | fmt       | Reformat paragraph text                          |
| X   | fold      | Wrap input lines to fit in specified width       |
| X   | groups    | Print group names a user is in                   |
| X   | head      | Output the first part of files                   |
| X   | hostid    | Print numeric host identifier                    |
| X   | hostname  | Print or set system name                         |
| X   | id        | Print user identity                              |
| X   | install   | Copy files and set attributes                    |
| X   | join      | Join lines on a common field                     |
| X   | kill      | Send a signal to processes                       |
| X   | link      | Make a hard link via the link syscall            |
| X   | ln        | Make links between files                         |
| X   | logname   | Print current login name                         |
| X   | ls        | List directory contents                          |
| X   | md5sum    | Print or check MD5 digests                       |
| X   | mkdir     | Make directories                                 |
| X   | mkfifo    | Make FIFOs (named pipes)                         |
| X   | mknod     | Make block or character special files            |
| X   | mktemp    | Create temporary file or directory               |
| X   | mv        | Move (rename) files                              |
| X   | nice      | Run a command with modified niceness             |
| X   | nl        | Number lines and write files                     |
| X   | nohup     | Run a command immune to hangups                  |
| X   | nproc     | Print the number of available processors         |
| X   | numfmt    | Reformat numbers                                 |
| X   | od        | Write files in octal or other formats            |
| X   | paste     | Merge lines of files                             |
| X   | pathchk   | Check file name validity and portability         |
| X   | pinky     | Lightweight finger                               |
| X   | pr        | Paginate or columnate files for printing         |
| X   | printenv  | Print all or some environment variables          |
| X   | printf    | Format and print data                            |
| X   | ptx       | Produce permuted indexes                         |
| X   | pwd       | Print working directory                          |
| X   | readlink  | Print value of a symlink or canonical file name  |
| X   | realpath  | Print the resolved file name.                    |
| X   | rm        | Remove files or directories                      |
| X   | rmdir     | Remove empty directories                         |
| X   | runcon    | Run a command in specified SELinux context       |
| X   | seq       | Print numeric sequences                          |
| X   | sha1sum   | Print or check SHA-1 digests                     |
| X   | sha224sum | Print or check SHA-2 224 bit digests             |
| X   | sha256sum | Print or check SHA-2 256 bit digests             |
| X   | sha384sum | Print or check SHA-2 384 bit digests             |
| X   | sha512sum | Print or check SHA-2 512 bit digests             |
| X   | shred     | Remove files more securely                       |
| X   | shuf      | Shuffling text                                   |
| X   | sleep     | Delay for a specified time                       |
| X   | sort      | Sort text files                                  |
| X   | split     | Split a file into pieces.                        |
| X   | stat      | Report file or file system status                |
| X   | stdbuf    | Run a command with modified I/O stream buffering |
| X   | stty      | Print or change terminal characteristics         |
| X   | sum       | Print checksum and block counts                  |
| X   | sync      | Synchronize cached writes to persistent storage  |
| X   | tac       | Concatenate and write files in reverse           |
| X   | tail      | Output the last part of files                    |
| X   | tee       | Redirect output to multiple files or processes   |
| X   | test      | Check file types and compare values              |
| X   | timeout   | Run a command with a time limit                  |
| X   | touch     | Change file timestamps                           |
| X   | tr        | Translate, squeeze, and/or delete characters     |
| V   | true      | Do nothing, successfully                         |
| X   | truncate  | Shrink or extend the size of a file              |
| X   | tsort     | Topological sort                                 |
| X   | tty       | Print file name of terminal on standard input    |
| X   | uname     | Print system information                         |
| X   | unexpand  | Convert spaces to tabs                           |
| X   | uniq      | Uniquify files                                   |
| X   | unlink    | Remove files via the unlink syscall              |
| X   | uptime    | Print system uptime and load                     |
| X   | users     | Print login names of users currently logged in   |
| X   | vdir      | Verbosely list directory contents                |
| X   | wc        | Print newline, word, and byte counts             |
| X   | who       | Print who is currently logged in                 |
| X   | whoami    | Print effective user ID                          |
| X   | yes       | Print a string until interrupted                 |