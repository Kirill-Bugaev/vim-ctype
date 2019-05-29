if !exists('g:ctype_autostart')
	let g:ctype_autostart = 1
endif

if !exists('g:ctype_filetypes')
	let g:ctype_filetypes = []
	call add(g:ctype_filetypes, '*.c')
	call add(g:ctype_filetypes, '*.cpp')
	call add(g:ctype_filetypes, '*.h')
endif

if !exists('g:ctype_oncursorhold')
	let g:ctype_oncursorhold = 0
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

if !exists('g:ctype_mode')
	let g:ctype_mode = 0
endif

if !exists('g:ctype_tmpdir')
	let g:ctype_tmpdir = '/tmp'
endif

if !exists('g:ctype_getmethod')
	let g:ctype_getmethod = 'source'
endif

if !exists('g:ctype_astdir')
	let g:ctype_astdir = '/tmp'
endif

if !exists('g:ctype_reparsetu')
	let g:ctype_reparsetu = 1
endif

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
	let g:ctype_cdb_method = 4
endif

if !exists('g:ctype_cdb_autoload')
	let g:ctype_cdb_autoload = 1
endif

if !exists('g:ctype_cdb_showerrormsg')
	let g:ctype_cdb_showerrormsg = 0
endif

let g:ctype_prefixname = 'ctype-'
let g:ctype_socket_file = 'empty'
let g:ctype_servcontresp = 0
" On mode 1 and 2 we need to save for each buffer:
" 	.tmpfile
"	.modified
"	.writerr
let g:ctype_mode_1_2_tmpbufentr = {}
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
let s:server_response_count = 0
let s:timerid = -1
let s:sent = 0
let s:lnum = 0
let s:colnum = 0

func s:StopServer_OnVimLeave()
	call s:StopServer(0)
endfunc

func s:OnCursorHold()
	call s:SaveBufToTmp()
	call ctype#GetType(function('s:ShowType'))
endfunc

func s:OnCursorMoved()
	let s:sent = 0
endfunc

func s:MainEvent(event)
	if !&modified || (g:ctype_mode == 1 && mode()[0] ==# 'n') || g:ctype_mode == 2
		exe 'call s:On' . a:event . '()'
	else 
		let g:ctype_type = ''
	endif
endfunc

func s:SaveBufToTmp()
	let bufnum = bufnr('%')
	if g:ctype_mode_1_2_tmpbufentr[bufnum].modified == 1
		try
			call writefile(getline(1, '$'), g:ctype_mode_1_2_tmpbufentr[bufnum].tmpfile)
			let g:ctype_mode_1_2_tmpbufentr[bufnum].modified = 0
			let g:ctype_mode_1_2_tmpbufentr[bufnum].writerr = 0
		catch
			if g:ctype_mode_1_2_tmpbufentr[bufnum].writerr == 0
				let g:ctype_mode_1_2_tmpbufentr[bufnum].writerr = 1
				echoerr "ctype: can't write temporary file with buffer content. " .
							\ 'Check g:ctype_tmpdir option value.'
			endif
		endtry
	endif
endfunc

func s:EchoClangRequestError(errcode)
	if g:ctype_server_showerrormsg && (!exists('b:ctype_lastclreqerr') ||
				\ b:ctype_lastclreqerr != a:errcode)
		if a:errcode == 1
			let msg = "can't get source file status (stat() C function)"
		elseif a:errcode == 2
			let msg = "can't find old entry in cache"
		elseif a:errcode == 3
			let msg = "can't allocate memory for new Translation Unit item"
		elseif a:errcode == 4
			let msg = "can't concatenate AST file path strings (memory allocation error)"
		elseif a:errcode == 5
			let msg = "can't create temporary file for AST"
		elseif a:errcode == 6
			let msg = "can't start child process"
		elseif a:errcode == 7
			let msg = "can't wait for child process to change state (waitpid() C function"
		elseif a:errcode == 8
			let msg = "child process can't change working directory"
		elseif a:errcode == 9
			let msg = "can't escape command line arguments (memory allocation error)"
		elseif a:errcode == 10
			let msg = "can't concatenate command line arguments (memory allocation error)"
		elseif a:errcode == 11
			let msg = "can't execute clang"
		elseif a:errcode == 12
			let msg = "can't make AST file"
		elseif a:errcode == 13
			let msg = "can't parse clang command line arguments file (memory allocation error)"
		elseif a:errcode == 14
			let msg = "can't add '-x c++' to clang command line arguments (memory allocation error)"
		elseif a:errcode == 15
			let msg = "can't get desired type"
		endif
		echoerr g:ctype_prefixname . s:server_name . ': ' . msg
		let b:ctype_lastclreqerr = a:errcode
	endif
endfunc

func s:ShowType(chan, msg)
	if a:msg[0] ==# '@'
		let type = a:msg[1:]
	else
		call s:EchoClangRequestError(a:msg)
		return
	endif
	
	if g:ctype_echo
		echo type
	endif
	let g:ctype_type = type
	if g:ctype_updatestl
		call setwinvar(winnr(), '&statusline', &statusline)
	endif
endfunc

func s:TimerHandler(timer)
	if s:server_pid == -1
		return
	endif

	let bt = getbufvar(bufnr('%'), '&filetype') 
	if bt == 'c' || bt == 'cpp'
		if g:ctype_mode == 2 || (g:ctype_mode == 1 && mode()[0] ==# 'n')
			call s:SaveBufToTmp()
		endif
		
		let [lnum, colnum] = getcurpos()[1:2]
		if lnum == s:lnum && colnum == s:colnum
			if !s:sent
				call ctype#GetType(function('s:ShowType'))
				let s:sent = 1
			endif	
		else
			let s:lnum = lnum
			let s:colnum = colnum
		endif
	endif
endfunc

" Set buffer modified state and create temporary file for buffer
func s:SetModAndTmp_OnBufAdd(bufnum)
	let g:ctype_mode_1_2_tmpbufentr[a:bufnum] = {}
	let g:ctype_mode_1_2_tmpbufentr[a:bufnum].modified =
				\ getbufvar(a:bufnum, '&modified')
	let cmd = 'mktemp '
	if expand('<afile>:e') == 'c'
		let cmd .= '--suffix=.c'
	else
		let cmd .= '--suffix=.cpp'
	endif
	let cmd .= ' ' . fnameescape(g:ctype_tmpdir) . '/' . 'ctypebuf.tmp.XXXXXXXXXX'
	let tmp = system(cmd)
	let g:ctype_mode_1_2_tmpbufentr[a:bufnum].tmpfile = tmp[:len(tmp) - 2]
	let g:ctype_mode_1_2_tmpbufentr[a:bufnum].writerr = 0
endfunc

func s:SetModAndTmp_OnVimEnter()
	for buf_i in getbufinfo()
		let buf_ft = getbufvar(buf_i.bufnr, '&filetype')
		if buf_ft == 'c' || buf_ft == 'cpp'
			call s:SetModAndTmp_OnBufAdd(buf_i.bufnr)
		endif
	endfor
endfunc

func s:DeleteTmpBufEntries_OnBufDelete(bufnum)
	if exists('g:ctype_mode_1_2_tmpbufentr['.a:bufnum.']')
		call delete(g:ctype_mode_1_2_tmpbufentr[a:bufnum].tmpfile)
		call remove(g:ctype_mode_1_2_tmpbufentr, a:bufnum)
	endif
endfunc

func s:ServerResponse(chan, msg)
	if s:server_response_count == 0
		let s:server_pid = a:msg
	elseif s:server_response_count == 1
		let g:ctype_socket_file = a:msg
		augroup ctype
			au!
			au VimLeave * call s:StopServer_OnVimLeave()
			if g:ctype_oncursorhold
				exe 'au CursorHold,CursorHoldI ' . join(g:ctype_filetypes, ',') .
							\ " call s:MainEvent('CursorHold')"
				if g:ctype_mode == 1
					exe 'au InsertLeave ' . join(g:ctype_filetypes, ',') .
								\ ' call s:SaveBufToTmp()'
				endif
			else
				exe 'au CursorMoved,CursorMovedI ' . join(g:ctype_filetypes, ',') .
							\ " call s:MainEvent('CursorMoved')"
				let s:timerid = timer_start(g:ctype_timeout,
							\ function('s:TimerHandler'), {'repeat': -1})
			endif
			au BufEnter * let g:ctype_type = ''

			if g:ctype_mode != 0
				exe 'au TextChanged,TextChangedI,TextChangedP ' .
							\ join(g:ctype_filetypes, ',') .
							\ " let g:ctype_mode_1_2_tmpbufentr[expand('<abuf>')].modified = 1"
				exe 'au BufAdd ' . join(g:ctype_filetypes, ',') .
							\ " call s:SetModAndTmp_OnBufAdd(expand('<abuf>'))"
				if v:vim_did_enter
					call s:SetModAndTmp_OnVimEnter()
				else
					au VimEnter * call s:SetModAndTmp_OnVimEnter()
				endif
				exe 'au BufDelete ' . join(g:ctype_filetypes, ',') .
							\ " call s:DeleteTmpBufEntries_OnBufDelete(expand('<abuf>'))"
			endif
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

func s:ServerControlResponse(chan, msg)
	if a:msg == 1
		let g:ctype_servcontresp = 1
	elseif a:msg == 2
		let g:ctype_servcontresp = 2
	endif
endfunc

func s:StartServer(showmsg)
	if s:server_pid != -1
		if a:showmsg || g:ctype_server_showerrormsg
			echoerr g:ctype_prefixname . s:server_name . ': already run'
		endif
		return
	endif

	let s:sent = 0
	let s:server_response_count = 0
	let s:server_job = job_start(s:server_cmd,
				\ {'out_cb': function('s:ServerResponse'),
				\ 'exit_cb': function('s:ServerExit')})
	if job_status(s:server_job) ==# 'fail'
		if a:showmsg || g:ctype_server_showerrormsg
			echoerr g:ctype_prefixname . s:server_name . ": can't start"
		endif
		return
	endif

	if a:showmsg
		echom g:ctype_prefixname . s:server_name . ': started'
	endif
endfunc

func s:StopServer(showadmsg)
	if s:server_pid == -1
		if a:showadmsg
			echoerr g:ctype_prefixname . s:server_name . ': already down'
		endif
		return
	endif
	
	call timer_stop(s:timerid)
	augroup ctype
		au!
	augroup END
	for key in keys(g:ctype_mode_1_2_tmpbufentr)
		call delete(g:ctype_mode_1_2_tmpbufentr[key].tmpfile)
	endfor
	let g:ctype_mode_1_2_tmpbufentr = {}
	let g:ctype_type = ''
	if g:ctype_updatestl
		call setwinvar(winnr(), '&statusline', &statusline)
	endif

	call ctype#SendControlQueryToServer(2, function('s:ServerControlResponse'))
	" Need wait on VimLeave
	let timeout = 1000
	let sleeptime = 10
	let elapsedtime = 0
	while g:ctype_servcontresp != 2 && elapsedtime <= timeout
		exe 'sleep ' . sleeptime . ' m'
		let elapsedtime += sleeptime
	endwhile
	if g:ctype_servcontresp == 2
		echom g:ctype_prefixname . s:server_name . ': stopped'
	else
		echoerr g:ctype_prefixname . s:server_name . ': no response (down?)'
	endif

	let s:server_pid = -1
endfunc

func s:RestartServer()
	call s:StopServer(0)
	call s:StartServer(1)
endfunc

func s:CheckServer()
	call ctype#SendControlQueryToServer(1, function('s:ServerControlResponse'))
	" Wait response
	let timeout = 1000
	let sleeptime = 10
	let elapsedtime = 0
	while g:ctype_servcontresp != 1 && elapsedtime <= timeout
		exe 'sleep ' . sleeptime . ' m'
		let elapsedtime += sleeptime
	endwhile
	if g:ctype_servcontresp == 1
		echom g:ctype_prefixname . s:server_name . ' is running'
	else
		echoerr g:ctype_prefixname . s:server_name . ': no response (down?)'
	endif
endfunc

if g:ctype_autostart
	call s:StartServer(0)
endif

" cdb facility
let g:ctype_chan_cdb = {}
let g:ctype_cdb = {}

func s:LoadCDB_OnVimEnter()
	for buf_i in getbufinfo()
		let buf_ft = getbufvar(buf_i.bufnr, '&filetype')
		if buf_ft == 'c' || buf_ft == 'cpp'
			call ctypecdb#GetCDB_Entries(buf_i.bufnr, bufname(buf_i.bufnr))
		endif
	endfor
endfunc

func s:LoadCDB_OnBufAdd()
	call ctypecdb#GetCDB_Entries(expand('<abuf>'), expand('<afile>'))
endfunc

func s:DeleteCDB_OnBufDelete()
	call remove(g:ctype_cdb, expand('<abuf>'))
endfunc

if g:ctype_cdb_method > 0
	augroup ctype-cdb
		au!
		if v:vim_did_enter
			call s:LoadCDB_OnVimEnter()
		else
			au VimEnter * call s:LoadCDB_OnVimEnter()
		endif
		exe 'au BufAdd ' . join(g:ctype_filetypes, ',') . ' call s:LoadCDB_OnBufAdd()'
		exe 'au BufDelete ' . join(g:ctype_filetypes, ',') .
					\ ' call s:DeleteCDB_OnBufDelete()'
	augroup END
endif

func s:UpdateCDB(bufnum)
	let ftype = getbufvar(a:bufnum, "&filetype")
	if ftype != 'c' && ftype != 'cpp'
		return
	endif
	
	call remove(g:ctype_cdb, a:bufnum)
	call ctypecdb#GetCDB_Entries(a:bufnum, bufname(a:bufnum))
endfunc

func s:UpdateCDBAll()
	for buf_i in getbufinfo()
		call s:UpdateCDB(buf_i.bufnr)
	endfor
endfunc

command! -bar -nargs=0 CTypeStart
			\ call s:StartServer(1)
command! -bar -nargs=0 CTypeStop
			\ call s:StopServer(1)
command! -bar -nargs=0 CTypeStartServer
			\ call s:StartServer(1)
command! -bar -nargs=0 CTypeStopServer
			\ call s:StopServer(1)
command! -bar -nargs=0 CTypeRestartServer
			\ call s:RestartServer()
command! -bar -nargs=0 CTypeCheckServer
			\ call s:CheckServer()
command! -bar -nargs=0 CTypeUpdateCDBCurrent
			\ call s:UpdateCDB(bufnr('%'))
command! -bar -nargs=0 CTypeUpdateCDBAll
			\ call s:UpdateCDBAll()
