# coreutils in V

This repository contains programs equivalent to GNU
[coreutils](https://www.gnu.org/software/coreutils/), written in the
[V language](https://vlang.io).

## Goal

Complete set of coreutils, written as closely as possible to the POSIX spec,
with as many GNU extensions as feasible.

We are looking for solid, working implementations of the commands, not 100%
1-to-1 parity, especially not quirks and unintended side-effects.

## Layout

Each command has it's own separate subdirectory under `src`, in case the
implementor wishes to create multiple `.v` files to implement a command, or add
a README.md specifically for that command.

## Building

Running `make` or `v run build.vsh` will build all the programs in `bin/`.

## Contributing

Contributions are welcome!

Please only contribute versions of the original utilities written in V.
Contributions written in other langauges will likely be rejected.

## Completed (10/109)

| Done    | Cmd       | Descripton                                       |
| :-----: |-----------|--------------------------------------------------|
|         | **[**     | Alternate form of `test`                         |
|         | arch      | Print machine hardware name                      |
|         | b2sum     | Print or check BLAKE2 digests                    |
|         | base32    | Transform data into printable data               |
|         | base64    | Transform data into printable data               |
|         | basename  | Strip directory and suffix from a file name      |
|         | basenc    | Transform data into printable data               |
| &check; | cat       | Concatenate and write files                      |
|         | chcon     | Change SELinux context of file                   |
|         | chgrp     | Change group ownership                           |
|         | chmod     | Change access permissions                        |
|         | chown     | Change file owner and group                      |
|         | chroot    | Run a command with a different root directory    |
|         | cksum     | Print CRC checksum and byte counts               |
|         | comm      | Compare two sorted files line by line            |
|         | coreutils | Multi-call program                               |
|         | cp        | Copy files and directories                       |
|         | csplit    | Split a file into context-determined pieces      |
|         | cut       | Print selected parts of lines                    |
|         | date      | Print or set system date and time                |
|         | dd        | Convert and copy a file                          |
|         | df        | Report file system disk space usage              |
|         | dir       | Briefly list directory contents                  |
|         | dircolors | Color setup for ls                               |
|         | dirname   | Strip last file name component                   |
|         | du        | Estimate file space usage                        |
| &check; | echo      | Print a line of text                             |
|         | env       | Run a command in a modified environment          |
|         | expand    | Convert tabs to spaces                           |
|         | expr      | Evaluate expressions                             |
| &check; | factor    | Print prime factors                              |
| &check; | false     | Do nothing, unsuccessfully                       |
|         | fmt       | Reformat paragraph text                          |
|         | fold      | Wrap input lines to fit in specified width       |
|         | groups    | Print group names a user is in                   |
|         | head      | Output the first part of files                   |
|         | hostid    | Print numeric host identifier                    |
|         | hostname  | Print or set system name                         |
|         | id        | Print user identity                              |
|         | install   | Copy files and set attributes                    |
|         | join      | Join lines on a common field                     |
|         | kill      | Send a signal to processes                       |
|         | link      | Make a hard link via the link syscall            |
|         | ln        | Make links between files                         |
| &check; | logname   | Print current login name                         |
|         | ls        | List directory contents                          |
|         | md5sum    | Print or check MD5 digests                       |
|         | mkdir     | Make directories                                 |
|         | mkfifo    | Make FIFOs (named pipes)                         |
|         | mknod     | Make block or character special files            |
|         | mktemp    | Create temporary file or directory               |
|         | mv        | Move (rename) files                              |
|         | nice      | Run a command with modified niceness             |
|         | nl        | Number lines and write files                     |
|         | nohup     | Run a command immune to hangups                  |
|         | nproc     | Print the number of available processors         |
|         | numfmt    | Reformat numbers                                 |
|         | od        | Write files in octal or other formats            |
|         | paste     | Merge lines of files                             |
|         | pathchk   | Check file name validity and portability         |
|         | pinky     | Lightweight finger                               |
|         | pr        | Paginate or columnate files for printing         |
| &check; | printenv  | Print all or some environment variables          |
|         | printf    | Format and print data                            |
|         | ptx       | Produce permuted indexes                         |
|         | pwd       | Print working directory                          |
|         | readlink  | Print value of a symlink or canonical file name  |
|         | realpath  | Print the resolved file name                     |
|         | rm        | Remove files or directories                      |
|         | rmdir     | Remove empty directories                         |
|         | runcon    | Run a command in specified SELinux context       |
|         | seq       | Print numeric sequences                          |
|         | sha1sum   | Print or check SHA-1 digests                     |
|         | sha224sum | Print or check SHA-2 224 bit digests             |
|         | sha256sum | Print or check SHA-2 256 bit digests             |
|         | sha384sum | Print or check SHA-2 384 bit digests             |
|         | sha512sum | Print or check SHA-2 512 bit digests             |
|         | shred     | Remove files more securely                       |
|         | shuf      | Shuffling text                                   |
| &check; | sleep     | Delay for a specified time                       |
|         | sort      | Sort text files                                  |
|         | split     | Split a file into pieces                         |
|         | stat      | Report file or file system status                |
|         | stdbuf    | Run a command with modified I/O stream buffering |
|         | stty      | Print or change terminal characteristics         |
|         | sum       | Print checksum and block counts                  |
|         | sync      | Synchronize cached writes to persistent storage  |
|         | tac       | Concatenate and write files in reverse           |
|         | tail      | Output the last part of files                    |
|         | tee       | Redirect output to multiple files or processes   |
|         | test      | Check file types and compare values              |
|         | timeout   | Run a command with a time limit                  |
|         | touch     | Change file timestamps                           |
|         | tr        | Translate, squeeze, and/or delete characters     |
| &check; | true      | Do nothing, successfully                         |
|         | truncate  | Shrink or extend the size of a file              |
|         | tsort     | Topological sort                                 |
|         | tty       | Print file name of terminal on standard input    |
|         | uname     | Print system information                         |
|         | unexpand  | Convert spaces to tabs                           |
|         | uniq      | Uniquify files                                   |
|         | unlink    | Remove files via the unlink syscall              |
|         | uptime    | Print system uptime and load                     |
|         | users     | Print login names of users currently logged in   |
|         | vdir      | Verbosely list directory contents                |
|         | wc        | Print newline, word, and byte counts             |
|         | who       | Print who is currently logged in                 |
| &check; | whoami    | Print effective user ID                          |
| &check; | yes       | Print a string until interrupted                 |

