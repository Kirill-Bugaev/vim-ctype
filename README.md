# vim-ctype

<img align="center" src="https://github.com/Kirill-Bugaev/vim-ctype/blob/master/vim-ctype.png" alt="screenshot">

Plugin uses [clang][] facility to determine type of instance
(type of variable, function, etc.) under cursor. So it is
necessary `clang` has been installed on system where plugin
will be used. ArchLinux users can do it with
```shell
# pacman -S clang
```
Main part is `clang-gettype` utility is written on C and 
had been compiled with `libclang version 8.0.0`. If you version
is different you may be should recompile `clang-gettype` and
`clang-cdb` programs in `./src/ctype` directory by `make` and
then install by `make install`.

`clang-gettype` utility is based on client-server architecture
using Unix domain sockets. Client accepts source code file and
location (line number and column) of instance as command line
arguments, send request to server and outputs type of specified
instance. Vimscript code wraps this functional.

Plugin works not with Vim buffers,
but with files which buffers correspond. By default if you 
have modified buffer you should save it before plugin can show
instance type. This behaviour can be changed by setting 
`g:ctype_mode = 1` or `g:ctype_mode = 2` (see below). In this case
plugin will work with modified buffer in Vim Normal Mode or in both
modes respectively. Temporary file for buffer
content will be created and rewritten each time you make
modification. This operation requires usage of system resources.
Solution is set `g:ctype_tmpdir = '/dev/shm'` and
`g:ctype_astdir = '/dev/shm'`. In this case temporary and AST
files will be written in memory that is mach faster then
writing on hard drive. Another is set
`g:ctype_getmethod = 'source'` (default value). In this case
plugin will parse source code directly without generating AST
file, but should be noticed that for parsing of C++ code AST
file is require, so it can be not appropriate.

For C++ code parsing AST file is required (I have a problem
with parsing C++ code from source file directly). Plugin generates
it automatically (for C++ code it will be generated regardless of
`g:ctype_getmethod` option value). AST file can be created only
for `compilable` source code. Frequently, source code can't be
compiled without appropriate command line arguments. If they are
absent AST file will not be created and plugin will not work.
Arguments can be specified in Compilation Database (it also is
required if not all types are displayed when you set
`g:ctype_getmethod = 'source'`). How to make Compilation Database
see below. If you set `g:ctype_getmethod = 'ast'` it
should be noticed that in this case to use plugin in
mode another then let `g:ctype_mode = 0` have little sense.

By default plugin shows instance type in Vim command line,
but this behavior can be changed. Last received instance type
always is available in `g:ctype_type` variable, so you can direct
output to Vim statusline:
```vim
set statusline += %{g:ctype_type}
let g:ctype_updatestl = 1
```

Also see [options][] section below.

## Options

### g:ctype_autostart
Defines would plugin starts automatically on Vim start.
If `0`  you can start manually by `CTypeStart`
command.
```vim
let g:ctype_autostart = 1
```
(boolean, default `1`)

### g:ctype_filetypes
There you can specify file types for which plugin will work.
```vim
let g:ctype_filetypes = ['*.c', '*.cpp', '*.h']
```
(list, default `['*.c', '*.cpp', '*.h']`)

### ctype_oncursorhold
If `1` plugin will request instance type on CursorHold
and CursorHoldI Vim autocmd events instead of timer events.
Delay between type value updates depends on `updatetime`
Vim configuration option.
```vim
let g:ctype_oncursorhold = 0
```
(boolean, default `0`)

### ctype_timeout
Time value (in milliseconds) after which plugin will repeat
request for type of instance under cursor and save modified
buffer into temporary file. Make sense only when
`g:ctype_oncursorhold = 0`.
```vim
let g:ctype_timeout = 100
```
(numeric, default `200`)

### ctype_echo
If `1` obtained type value will be echoed in Vim command line.
```vim
let g:ctype_echo = 0
```
(boolean, default `1`)

### ctype_updatestl
If `1` plugin will update Vim statusline after type value
obtained. Make sense when passing `g:ctype_type` variable
value to statusline.
```vim
let g:ctype_updatestl = 1
```
(boolean, default `undefined`)

### ctype_cleanonmove
If `1` plugin will clean current value of `g:ctype_type`
variable and update statusline on `CursorMoved` and 
`CursorMovedI` autocmd events. It is useful with 
`g:ctype_oncursorhold = 1` or high value of
`g:ctype_timeout` option, but may be cause of blinking
otherwise.
```vim
let g:ctype_cleanonmove = 1
```
(boolean, default `0`)

### g:ctype_mode
Defines plugin behavior on changes into buffer.

`0` means disable plugin until changes is written to file.
Translation Unit will be updated each time as writing.

`1` means disable plugin only for Vim Insert Mode until
changes is written to file. Translation Unit will be
updated on timer after each buffer modification
in Normal Mode.

`2` means not disable plugin at all. Translation
Units will be updated on timer after each modification
in both modes.

It has little sense to use modes `1` and `2` with
`g:ctype_getmethod = 'ast'` (see below) because this
method requires compilable source code which is not
always realized when you make corrections. So it is
better to set `g:ctype_getmethod = 'source'` (default
value) in this case. But you should to know that for
C++ code AST file will be generated anyway.

Also these modes require to save modified buffer in
temporary file to create Translation Unit. It may slow
down Vim. So I strongly recommend to set 
`g:ctype_tmpdir = '/dev/shm'` and
`g:ctype_astdir = '/dev/shm'` or another shared memory
directory.
```vim
let g:ctype_mode = 1
```
(numeric, default `1`)

### g:ctype_tmpdir
Defines temporary directory for saving changed buffers.
Make sense only with `g:ctype_mode = 1` or
`g:ctype_mode = 2`.
```vim
let g:ctype_tmpdir = '/dev/shm'
```
(string, default `'/tmp'`)

### g:ctype_getmethod
Method of retrieving data for clang Translation Units
which is used by plugin server to obtain required types.

`'ast'` means create AST file and retrieve data from it

`"source"` means retrieve data from source file directly

Notice that for C++ code parsing AST file is required, so 
it will be created regardless of this option value.
`g:ctype_getmethod = 'source'`. 
```vim
let g:ctype_getmethod = 'ast'
```
(string, default `'source'`)

### g:ctype_astdir
Defines temporary directory where AST files will be
created.

```vim
let g:ctype_astdir = '/dev/shm'
```
(string, default `'/tmp'`)

### g:ctype_reparsetu
Defines will Translation Unit be reparsed or created again
when source file is changed. Clang docs declare that reparse
is more more efficient. 

`0` means new Translation Unit will be created.

`1` means Translation Unit will be reparsed with the same
arguments which was used when Translation Unit had been
created.

Make sense only with `g:ctype_getmethod = 'source'`.
```vim
let g:ctype_reparsetu = 0
```
(boolean, default `1`)

### g:ctype_server_backlog
Defines the maximum length to which the queue of pending
connections for server socket may grow. Plugin
kills previous request to server before starts new.
So, in theory, this option shouldn't influence on plugin
work.
```vim
let g:ctype_server_backlog = 15
```
If you change this option after Vim starts you should
restart `ctype-server` by `CTypeRestartServer` command
in order to apply changes.

(numeric, default `10`)

### g:ctype_server_receivetimeout
Defines timeout (microseconds) for waiting request from
client on server. After this time elapsed request will
considered overdue and will not processed.
If your system is too slow you can try to increase this
value.
```vim
let g:ctype_server_receivetimeout = 20000
```
If you change this option after Vim starts you should
restart `ctype-server` by `CTypeRestartServer` command
in order to apply changes.

(numeric, default `10000`)

### g:ctype_server_cachesize
Server makes cache of `Translation Unit` created from `AST`
file generated for source code file which instance type
is requested. So it can process requests for the same
source code file much faster, because doesn't need
parse source code again. This option defines size of
`Translation Unit` cache. It means count of Translation
Units (source code files) which will be saved for
quick response. Minimum value is 1.
```vim
let g:ctype_server_cachesize = 10
```
If you change this option after Vim starts you should
restart `ctype-server` by `CTypeRestartServer` command
in order to apply changes.

(numeric, default `20`)

### g:ctype_server_clangpath
Defines path to `clang` frontend.
```vim
let g:ctype_server_clangpath = '/usr/bin/clang'
```
If you change this option after Vim starts you should
restart `ctype-server` by `CTypeRestartServer` command
in order to apply changes.

(string, default `/usr/bin/clang`)

### g:ctype_server_clangpppath
Defines path to `clang++`.
```vim
let g:ctype_server_clangpppath = '/usr/bin/clang++'
```
If you change this option after Vim starts you should
restart `ctype-server` by `CTypeRestartServer` command
in order to apply changes.

(string, default `/usr/bin/clang++`)

### g:ctype_server_showerrormsg
Defines will error messages from server be shown.
```vim
let g:ctype_server_showerrormsg = 1
```
(boolean, default `1`)

### g:ctype_client_clangcmdargs
Defines command line arguments which will be passed to
`clang` during `AST` file generation.
```vim
let g:ctype_client_clangcmdargs = '-I/usr/include/freetype2'
```
(string, default ` `)

### g:ctype_client_showerrormsg
Defines will error messages from client be shown.
```vim
let g:ctype_server_showerrormsg = 0
```
(boolean, default `0`)

### g:ctype_cdb_method
Plugin can find valid compile commands for source 
file in compilation database if it exists. You can
configure default behavior.

`0` means not use compilation database at all.

`1` means find first valid compile command arguments

`2` means find all valid compile commands

`3` means find first compile command arguments without
checking for validity

`4` means find all available compile commands without
checking for validity

```vim
let g:ctype_cdb_method = 2
```
(numeric, default `4`)

### g:ctype_cdb_autoload

`0` means show all founded compile commands arguments 
and provide user to choose appropriate

`1` means load first found compile command arguments
automatically

```vim
let g:ctype_cdb_autoload = 0
```
(boolean, default `1`)

### g:ctype_cdb_showerrormsg
Defines will error messages from compilation database
facility be shown.
```vim
let g:ctype_cdb_showerrormsg = 0
```
(boolean, default `0`)

### g:ctype_opttrack_timeout
Options tracker timer's timeout (in milliseconds).

Changing of `g:ctype_filetypes`, `g:ctype_oncursorhold`,
`g:ctype_timeout` and `g:ctype_mode` options
requires reset of autocommands and main timer. So plugin saves
local values of these options and checks changes on timer.
It allows change options after Vim start without restarting
plugin. If you don't need it set `g:ctype_opttrack_timeout = 0`.
```vim
let g:ctype_opttrack_timeout = 0
```
(numeric, default `1000`)

## Commands

### `CTypeStart`
Starts plugin work. Sets Compilation Database autocommands
and starts `ctype-server`.

### `CTypeStop`
Stops plugin work. Removes Compilation Database autocommands
and stops `ctype-server`.

### `CTypeStartServer`
Starts `ctype-server`.

### `CTypeStopServer`
Stops `ctype-server`.

### `CTypeRestartServer`
Restarts `ctype-server`.

### `CTypeCheckServer`
Checks `ctype-server` status.

### `CTypeUpdateCDBCurrent`
Updates Compilation DB arguments for current buffer.

### `CTypeUpdateCDBAll`
Updates Compilation DB arguments for all opened buffers.

## How to make Compilation Database
Some C and C++ projects are compiled using `Make` and `CMake`
facility. Often plugin can't work with source code files of
such projects, because additional command line arguments
(like `-I...` and `-D...`) are required for make `AST` file.
These command line arguments are specified in `Makefile` or
`CMakeLists.txt` files. The solution is generate Compilation
Database for such projects.

### CMake
Compilation Database can be generated for project uses `CMake`
simply with
```shell
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```
After running this command or adding
`set(CMAKE_EXPORT_COMPILE_COMMANDS ON)` line to
`CMakeLists.txt` script `compile_commands.json` file appears
in project root directory. It contains command line arguments 
for compilation process well then required for making `AST`
file. If `g:ctype_cdb_method` option is not `0`
plugin will find compilation arguments in this file
automatically and use it for making `AST`.

### Make
If project uses `Make` for compilation process Compilation
Database can be created manually. Let's view such case
simple example.

Assume we want to browse in Vim and watch types of instances
under cursor in `./cgdb/cgdb.cpp` source code file of [cgdb][]
project. If you just open this file in Vim you should notice
that plugin doesn't work because additional command line
arguments are required for compilation well then for
making `AST` file. Let's try to find out which exactly.

First of all try to create `AST` file manually with `clang`

```shell
$ clang++ -emit-ast cgdb/cgdb.cpp -o /dev/null
cgdb/cgdb.cpp:67:10: fatal error: 'sys_util.h' file not found
#include "sys_util.h"
         ^~~~~~~~~~~~
1 error generated.
```

We see that `sys_util.h` header file is required so we should
specify directory where it is contained with `-I...` command
line argument. This file is placed in `./lib/util`, besides
many other files from `./lib` directory are required. So we
will pass all `./lib` subdirectories as `-I...` command line
arguments.

```shell
$ clang++ -emit-ast cgdb/cgdb.cpp -o /dev/null -I lib/kui -I lib/rline -I lib/tgdb -I lib/tokenizer -I lib/util
In file included from cgdb/cgdb.cpp:67:
In file included from lib/util/sys_util.h:18:
lib/util/cgdb_clog.h:13:10: fatal error: 'config.h' file not found
#include "config.h"
         ^~~~~~~~~~
1 error generated.
```

Now we see that compiler can't find `config.h` header file and
it is really absent in not deployed `cgdb` project. Need fix it.
We should follow instructions which are described in `README.md`
file in root directory of `cgdb` project to deploy it. Let's
run `./autogen.sh` to generate configure script. 

```shell
$ ./autogen.sh
-- Update configure.in to reflect the new version number
-- Running aclocal
-- Running autoconf
-- Running autoheader
-- Running automake
configure.ac:9: installing 'config/compile'
configure.ac:18: installing 'config/config.guess'
configure.ac:18: installing 'config/config.sub'
configure.ac:6: installing 'config/install-sh'
configure.ac:6: installing 'config/missing'
cgdb/Makefile.am: installing 'config/depcomp'
configure.ac: installing 'config/ylwrap'
doc/Makefile.am:1: installing 'config/mdate-sh'
doc/Makefile.am:1: installing 'config/texinfo.tex'
```

After that we should run `./configure`.

```shell
$ ./configure
checking for a BSD-compatible install... /usr/bin/install -c
checking whether build environment is sane... yes
checking for a thread-safe mkdir -p... /usr/bin/mkdir -p
checking for gawk... gawk
...
config.status: creating config.h
config.status: executing depfiles commands
```

We see that `config.h` have been successfully created and
we should specify directory where it is contained (project root
directory `.`) with `-I...` command line arguments.

```shell
$ clang++ -emit-ast cgdb/cgdb.cpp -o /dev/null -I lib/kui -I lib/rline -I lib/tgdb -I lib/tokenizer -I lib/util -I .
cgdb/cgdb.cpp:729:26: error: variable has incomplete type 'struct option'
    static struct option long_options[] = {
                         ^
cgdb/cgdb.cpp:729:19: note: forward declaration of 'option'
    static struct option long_options[] = {
                  ^
cgdb/cgdb.cpp:1338:18: error: use of undeclared identifier 'SIGINT'
    if (signo == SIGINT) {
                 ^
cgdb/cgdb.cpp:1615:20: error: variable has incomplete type 'struct winsize'
    struct winsize size;
                   ^
cgdb/cgdb.cpp:1615:12: note: forward declaration of 'winsize'
    struct winsize size;
           ^
cgdb/cgdb.cpp:1631:18: error: use of undeclared identifier 'TIOCGWINSZ'
    if (ioctl(0, TIOCGWINSZ, &size) < 0)
                 ^
cgdb/cgdb.cpp:1634:24: error: use of undeclared identifier 'TIOCSWINSZ'
    if (ioctl(slavefd, TIOCSWINSZ, &size) < 0)
                       ^
5 errors generated.
```

Now it looks like `./cgdb/cgdb.cpp` source code file contains
syntax error, but more likely that we don't pass preprocessor
arguments like `-D...` is required for compilation. Let's run
`make` to check it.

```shell
$ make
make  all-recursive
make[1]: Entering directory '/data/Downloads/cgdb-make'
Making all in lib
make[2]: Entering directory '/data/Downloads/cgdb-make/lib'
Making all in util
make[3]: Entering directory '/data/Downloads/cgdb-make/lib/util'
...
g++ -DHAVE_CONFIG_H -DPKGDATADIR=\"/usr/local/share/cgdb\" -DTOPBUILDDIR=\"/data/Downloads/cgdb-make\" -I. -I..    -I../lib/kui -I../lib/rline -I../lib/util -I../lib/tgdb -I../lib/tokenizer -g -O2 -MT cgdb.o -MD -MP -MF .deps/cgdb.Tpo -c -o cgdb.o cgdb.cpp
...
```

Exactly. For successfully compilation `-DHAVE_CONFIG_H` preprocessor argument
is required. Let's specify it in our `clang` command.

```shell
$ clang++ -emit-ast cgdb/cgdb.cpp -o /dev/null -I lib/kui -I lib/rline -I lib/tgdb -I lib/tokenizer -I lib/util -I . -D HAVE_CONFIG_H
```

Now we see that `AST` file can be created without errors.
Remains only create Compilation Database files and plugin
will start to work.

You should create `compile_flags.txt` or
`compile_commands.json` (which, imho, is more preferable
because allows specify arguments for each source code
file of project separately) with arguments obtained above.


```
# compile_flags.txt

-D HAVE_CONFIG_H
-I .
-I lib/kui
-I lib/rline
-I lib/tgdb
-I lib/tokenizer
-I lib/util
```


```
# compile_commands.json (replace `directory` entry with your
# `cgdb` project root directory):

[
	{
		"directory": "/data/Downloads/cgdb-make",
	   	"file": "cgdb/cgdb.cpp",
	   	"arguments":
			[
				"clang++",
				"-D", "HAVE_CONFIG_H",
			   	"-I", ".",
			   	"-I", "lib/kui",
			   	"-I", "lib/rline",
			   	"-I", "lib/tgdb",
			   	"-I", "lib/tokenizer",
			   	"-I", "lib/util",
			]
	},
]
```

Also you can generate `compile_commands.json` automatically
using `-MJ` command line argument for `clang`. But be careful,
it creates new `compile_commands.json` file each time it runs, so previous
entries will be removed. And don't forget add `[` and `]`
brackets at the beginning and the end of `compile_commands.json`
file manually because `clang` creates it without, which is not
correct.

```
$ clang++ -emit-ast cgdb/cgdb.cpp -o /dev/null -I lib/kui -I lib/rline -I lib/tgdb -I lib/tokenizer -I lib/util -I . -D HAVE_CONFIG_H -MJ compile_commands.json
```

[clang]: https://clang.llvm.org/
[Options]: #Options
[cgdb]: https://github.com/cgdb/cgdb
