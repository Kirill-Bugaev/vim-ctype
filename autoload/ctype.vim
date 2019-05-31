" This file is part of vim-ctype plugin
"
let s:plugin_path = expand('<sfile>:p:h')
let s:client_path = s:plugin_path . '/../bin/ctype/client'
let s:client_name = 'client'

let s:client_job = job_start('none')

func s:ClientExit(job, exit_status)
	if a:exit_status == 0
		let b:ctype_lasterror = 0
		return
	endif

	let g:ctype_type = ''

	if g:ctype_client_showerrormsg && (!exists('b:ctype_lasterror') ||
				\ b:ctype_lasterror != a:exit_status)
		if a:exit_status == 1
			echoerr g:ctype_prefixname . s:client_name . ': not enough arguments'
		elseif a:exit_status == 2
			echoerr g:ctype_prefixname . s:client_name . ": can't access to socket file"
		elseif a:exit_status == 3
			echoerr g:ctype_prefixname . s:client_name . ': incorrect query type'
		elseif a:exit_status == 4
			echoerr g:ctype_prefixname . s:client_name . ": can't access to source file"
		elseif a:exit_status == 5
			echoerr g:ctype_prefixname . s:client_name . ": can't access to working directory"
		elseif a:exit_status == 6
			echoerr g:ctype_prefixname . s:client_name . ': invalid line number'
		elseif a:exit_status == 7
			echoerr g:ctype_prefixname . s:client_name . ': invalid column number'
		elseif a:exit_status == 8
			echoerr g:ctype_prefixname . s:client_name . ': invalid source file type'
		elseif a:exit_status == 9
			echoerr g:ctype_prefixname . s:client_name . ': invalid get method'
		elseif a:exit_status == 10
			echoerr g:ctype_prefixname . s:client_name . ": can't access to AST directory"
		elseif a:exit_status == 11
			echoerr g:ctype_prefixname . s:client_name . ': invalid reparse option'
		elseif a:exit_status == 12
			echoerr g:ctype_prefixname . s:client_name . ': invalid update TU flag'
		elseif a:exit_status == 13
			echoerr g:ctype_prefixname . s:client_name . ": can't create socket"
		elseif a:exit_status == 14
			echoerr g:ctype_prefixname . s:client_name . ": can't connect to server"
		elseif a:exit_status == 15
			echoerr g:ctype_prefixname . s:client_name . ": can't send request to server"
		elseif a:exit_status == 16
			echoerr g:ctype_prefixname . s:client_name . ": can't receive data from server"
		elseif a:exit_status == 17
			echoerr g:ctype_prefixname . s:client_name . ': clang request faild'
		endif
		echoerr g:ctype_prefixname . s:client_name . ' exited with code = ' . a:exit_status
	endif

	let b:ctype_lasterror = a:exit_status
endfunc

func ctype#GetType(callback)
	if job_status(s:client_job) ==# 'run'
		call job_stop(s:client_job)
	endif

	let [lnum, colnum] = getcurpos()[1:2]
	let cmd = fnameescape(s:client_path) . ' ' .
				\ fnameescape(g:ctype_socket_file) . ' 0 '
	
	" Pass source file or tmp file of modified source buffer
	if g:ctype_mode == 0 ||
				\ getfsize(g:ctype_mode_1_2_tmpbufentr[bufnr('%')].tmpfile) <= 0
		let cmd .= fnameescape(expand('%:p'))
	else
		let cmd .= fnameescape(g:ctype_mode_1_2_tmpbufentr[bufnr('%')].tmpfile)
	endif

	" working dir
	if g:ctype_cdb_method > 0 && exists('g:ctype_cdb['.bufnr('%').']')
		let cmd .= ' ' . fnameescape(g:ctype_cdb[bufnr('%')].workingdir)
	else
		let cmd .= ' ' . fnameescape(expand('%:p:h'))
	endif

	let cmd .=  ' ' . lnum . ' ' . colnum

	let ftype = getbufvar(bufnr('%'), '&filetype')
	if ftype == 'cpp'
		let cmd .= ' cpp'
	else
		let cmd .= ' c'
	endif

	if ftype == 'cpp'
		let method = 'ast'
	else
		let method = g:ctype_getmethod
	endif
	let cmd .= ' ' . method

	if method ==? 'ast'
		let cmd .= ' ' .g:ctype_astdir
	else
		let cmd .= ' ' . g:ctype_reparsetu
	endif

	let cmd .= ' "'

	" cdb args
	if g:ctype_cdb_method > 0 && exists('g:ctype_cdb['.bufnr('%').']')
		let cmd .= fnameescape(g:ctype_cdb[bufnr('%')].cmdargs) . ' '
	endif

	let cmd .= fnameescape(g:ctype_client_clangcmdargs)

	let cmd .= '"'

	if exists('g:ctype_updtu['.bufnr('%').']')
		call remove(g:ctype_updtu, bufnr('%'))
		let cmd .= ' 1'
	else
		let cmd .= ' 0'
	endif

	let s:client_job = job_start(cmd,
				\ {'out_cb': a:callback,
				\ 'exit_cb': function('s:ClientExit')})
endfunc

" server facility
func ctype#SendControlQueryToServer(query, callback)
	let g:ctype_servcontresp = 0
	let cmd = fnameescape(s:client_path) . ' ' .
				\ fnameescape(g:ctype_socket_file) . ' ' . a:query
	call job_start(cmd,
				\ {'out_cb': a:callback,
				\ 'exit_cb': function('s:ClientExit')})
endfunc
