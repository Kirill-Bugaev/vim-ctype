if !exists('g:ctype_server_backlog')
	let g:ctype_server_backlog = 10
endif

if !exists('g:ctype_server_receivetimeout')
	let g:ctype_server_receivetimeout = 10000
endif

if !exists('g:ctype_server_cachesize')
	let g:ctype_server_cachesize = 20
endif

if !exists('g:ctype_server_clangpath')
	let g:ctype_server_clangpath = '/usr/bin/clang'
endif

if !exists('g:ctype_server_clangpppath')
	let g:ctype_server_clangpppath = '/usr/bin/clang++'
endif

if !exists('g:ctype_server_showerrormsg')
	let g:ctype_server_showerrormsg = 1
endif

if !exists('g:ctype_client_clangcmdargs')
	let g:ctype_client_clangcmdargs = ''
endif

if !exists('g:ctype_client_showerrormsg')
	let g:ctype_client_showerrormsg = 0
endif

if !exists('g:ctype_cdb_method')
	let g:ctype_cdb_method = 1
endif

if !exists('g:ctype_cdb_showerrormsg')
	let g:ctype_cdb_showerrormsg = 0
endif

if !exists('g:ctype_timeout')
	let g:ctype_timeout = 200
endif

if !exists('g:ctype_echo')
	let g:ctype_echo = 1
endif

if !exists('g:ctype_updatestl')
	if g:ctype_echo
		let g:ctype_updatestl = 0
	else
		let g:ctype_updatestl = 1
	endif
endif

let g:ctype_prefixname = 'ctype-'
let g:ctype_socket_file = 'empty'
let g:ctype_type = ''

let s:plugin_path = expand('<sfile>:p:h')
let s:server_path = s:plugin_path . '/../bin/ctype/server'
let s:server_cmd = fnameescape(s:server_path) . ' ' .
			\ g:ctype_server_backlog . ' ' .
			\ g:ctype_server_receivetimeout . ' ' .
			\ g:ctype_server_cachesize . ' ' .
			\ '"' . g:ctype_server_clangpath . '" ' .
			\ '"' . g:ctype_server_clangpppath . '"'

let s:server_name = 'server'
let s:server_pid = -1
let s:server_uid = ''
let s:server_response_count = 0

func s:ServerResponse(chan, msg)
	if s:server_response_count == 0
		let s:server_pid = a:msg
		let s:server_uid = system('ps --no-headers -o lstart,cmd --pid '
					\ . s:server_pid)
		if s:server_uid !~ s:server_name
			let server_pid = -1
			let s:server_uid = ''
			echoerr 'vim-ctype: ' . g:ctype_prefixname . s:server_name . ' failed'
		endif
	elseif s:server_response_count == 1
		let g:ctype_socket_file = a:msg
		augroup ctype
			au!
			if exists('g:ctype_oncursorhold') && g:ctype_oncursorhold
				au CursorHold,CursorHoldI *.c,*.cpp
							\ if !&modified |
							\ call ctype#GetType(function('s:ShowType')) |
							\ else |
							\ let g:ctype_type = '' |
							\ endif
			else
				au CursorMoved,CursorMovedI *.c,*.cpp
							\ if !&modified |
							\ let s:shown = 0 |
							\ else |
							\ let g:ctype_type = '' |
							\ endif
				call timer_start(g:ctype_timeout,
							\ function('s:TimerHandler'), {'repeat': -1})
			endif
			au BufEnter * let g:ctype_type = ''
		augroup END
	endif
	let s:server_response_count +=1
endfunc

func s:ServerExit(job, exit_status)
	if a:exit_status == 0
		return
	endif

	if g:ctype_server_showerrormsg
		if a:exit_status == 1
			echoerr g:ctype_prefixname . s:server_name . ": can't fork"
		elseif a:exit_status == 2
			echoerr g:ctype_prefixname . s:server_name . ": can't close/redirect std*"
		elseif a:exit_status == 3
			echoerr g:ctype_prefixname . s:server_name . ': invalid backlog'
		elseif a:exit_status == 4
			echoerr g:ctype_prefixname . s:server_name . ': invalid socket receive timeout'
		elseif a:exit_status == 5
			echoerr g:ctype_prefixname . s:server_name . ': invalid cache size'
		elseif a:exit_status == 6
			echoerr g:ctype_prefixname . s:server_name . ': clang frontend not found'
		elseif a:exit_status == 7
			echoerr g:ctype_prefixname . s:server_name . ": can't create socket file"
		elseif a:exit_status == 8
			echoerr g:ctype_prefixname . s:server_name . ": can't create socket"
		elseif a:exit_status == 9
			echoerr g:ctype_prefixname . s:server_name . ": can't assign address to socket (bind() error)"
		elseif a:exit_status == 10
			echoerr g:ctype_prefixname . s:server_name . ": can't mark socket as passive (listen() error)"
		elseif a:exit_status == 11
			echoerr g:ctype_prefixname . s:server_name . ": can't extract connection request (accept() error)"
		elseif a:exit_status == 12
			echoerr g:ctype_prefixname . s:server_name . ": can't set signals handler"
		elseif a:exit_status == 13
			echoerr g:ctype_prefixname . s:server_name . ": can't initialize cache"
		endif
		echoerr g:ctype_prefixname . s:server_name . ' exited with code = ' . a:exit_status
	endif
endfunc

" Start server
let s:server_job = job_start(s:server_cmd,
			\ {'out_cb': function('s:ServerResponse'),
			\ 'exit_cb': function('s:ServerExit')})
if job_status(s:server_job) ==# 'fail'
	echoerr "vim-ctype: can't start " . g:ctype_prefixname . s:server_name
endif

func s:KillServer()
	if s:server_pid == -1
		return
	endif

	let l:server_uid = system('ps --no-headers -o lstart,cmd --pid ' . s:server_pid)
	if l:server_uid !=# s:server_uid || l:server_uid !~ s:server_name
		return
	endif

	exe ':!kill ' . s:server_pid
endfunc

augroup clang-gettype-server
	au!
	au VimLeave * call s:KillServer()
augroup END

let s:shown = 1
let s:lnum = 0
let s:colnum = 0

func s:TimerHandler(timer)
	if s:server_pid == -1
		return
	endif

	let [lnum, colnum] = getcurpos()[1:2]
	if lnum == s:lnum && colnum == s:colnum
		if !s:shown
			call ctype#GetType(function('s:ShowType'))
			let s:shown = 1
		endif	
	else
		let s:lnum = lnum
		let s:colnum = colnum
	endif
endfunc

func s:ShowType(chan, type)
	if g:ctype_echo
		echo a:type
	endif
	let g:ctype_type = a:type
	if g:ctype_updatestl
		call setwinvar(winnr(), '&statusline', &statusline)
	endif
endfunc

" cdb facility
if g:ctype_cdb_method > 0
	augroup ctype-cdb
		au!
		au VimEnter * call s:LoadCDB_OnVimEnter()
		au BufAdd *.c,*.cpp call s:LoadCDB_OnBufAdd()
		au BufDelete *.c,*.cpp call s:DeleteCDB_OnBufDelete()
	augroup END
endif

let g:ctype_chan_cdb = {}
let g:ctype_cdb = {}

func s:LoadCDB_OnVimEnter()
	for buf_i in getbufinfo()
		let buf_ft = fnamemodify(buf_i.name, ':e')
		if buf_ft ==# 'c' || buf_ft ==# 'cpp'
			call ctypecdb#GetCDB_Entries(buf_i.bufnr, bufname(buf_i.bufnr),
						\ g:ctype_cdb_method)
		endif
	endfor
endfunc

func s:LoadCDB_OnBufAdd()
	call ctypecdb#GetCDB_Entries(expand('<abuf>'), expand('<afile>'),
				\ g:ctype_cdb_method)
endfunc

func s:DeleteCDB_OnBufDelete()
	call remove(g:ctype_cdb, expand('<abuf>'))
endfunc

