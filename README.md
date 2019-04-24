# vim-ctype

Plugin uses [clang][] facility to determine type of instance
(type of variable, function, etc.) under cursor. So it is
necessary `clang` has been installed on system where plugin
will be used. ArchLinux users can do it with
```shell
# pacman -S clang
```

Plugin works not with Vim buffers,
but with files which buffers correspond. So if you have modified
buffer you should save it before plugin can show instance type.
Also should be noted that plugin works correctly only with
source code for which `AST` file can be created without errors
(file should be compilable).

Main part is `clang-gettype` utility is written on C.
It based on client-server architecture using unix domain sockets.
Client accepts source code file and location
(line number and column) of instance as command line arguments,
send request to server and outputs type of specified instance.
Vimscript code wraps this functional.
By default it shows instance type in Vim command line,
but this behavior can be changed. Last received instance type
always is available in `g:ctype_type` variable, so you can direct
output to Vim statusline:
```vim
set statusline += %{g:ctype_type}
```
Also see [options][] section below.

## Options

### g:ctype_server_backlog
Defines the maximum length to which the queue of pending
connections for server socket may grow. Plugin
kill previous request to server before start new.
So, in theory, this option shouldn't influence on plugin
work.
```vim
let g:ctype_server_backlog = 15
```
(numeric, default `10`)

### g:ctype_server_receivetimeout
Defines timeout (microseconds) for waiting request from
client on server. After this time elapsed request will
considered overdue and will not processed by server.
If your system is too slow you can try to increase this
value.
```vim
let g:ctype_server_receivetimeout = 20000
```
(numeric, default `10000`)

### g:ctype_server_cachesize
Server make cache of `Translation Unit` created from `AST`
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
(numeric, default `20`)

### g:ctype_server_clangpath
Defines path to `clang` frontend.
```vim
let g:ctype_server_clangpath = '/usr/bin/clang'
```
(string, default `/usr/bin/clang`)

### g:ctype_server_clangpppath
Defines path to `clang++`.
```vim
let g:ctype_server_clangpppath = '/usr/bin/clang++'
```
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
configure default behavior. Value `0` means not use
compilation database at all. `1` means use first
valid compile command arguments. `2` means
print all valid compile commands and provide
user to choose appropriate.

Warning! Now methods `1` and `2` work identically
because I don't know how to display compile commands
variants and give user opportunity to choose
appropriate in Vim asynchronously. So I have
commented code (`autoload/clangcdb.vim`
`s:ChooseCompileCommand()` function) which displays
compile commands variants as Vim command line echo.
```vim
let g:ctype_cdb_method = 2
```
(numeric, default `1`)

### g:ctype_cdb_showerrormsg
Defines will error messages from compilation database
facility be shown.
```vim
let g:ctype_cdb_showerrormsg = 0
```
(boolean, default `0`)

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
request for type of instance under cursor. Make sense only
when `g:ctype_oncursorhold = 0`.
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
If `1` plugin will update statusline after type value
obtained. Make sense when passing `g:ctype_type` variable
value to Vim statusline.
```vim
let g:ctype_updatestl = 1
```
(boolean, default `undefined`)

[clang]: https://clang.llvm.org/
[Options]: #Options
