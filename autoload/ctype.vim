let s:plugin_path = expand('<sfile>:p:h')
let s:client_path = s:plugin_path . '/../bin/clang-gettype-client'
let s:client_name = 'clang-gettype-client'

let s:client_job = job_start('none')

func s:ClientExit(job, exit_status)
	if a:exit_status == 0
		let b:ctype_lasterror = 0
		return
	endif

	let g:ctype_type = ''
	let b:ctype_lasterror = a:exit_status
	let b:ctype_lastmodified = system('stat -c %Y ' . fnameescape(bufname('%')))

	if g:ctype_client_showerrormsg && (!exists('b:ctype_lasterror') ||
				\ b:ctype_lasterror != a:exit_status)
		if a:exit_status == 1
			echoerr s:client_name . ': not enough arguments'
		elseif a:exit_status == 2
			echoerr s:client_name . ': invalid cursor position'
		elseif a:exit_status == 3
			echoerr s:client_name . ": can't create socket"
		elseif a:exit_status == 4
			echoerr s:client_name . ": can't connect to server"
		elseif a:exit_status == 5
			echoerr s:client_name . ": can't send request to server"
		elseif a:exit_status == 6
			echoerr s:client_name . ": can't receive data from server"
		endif
		echoerr s:client_name . ' exited with code = ' . a:exit_status
	endif
endfunc

func ctype#GetType(callback)
	if job_status(s:client_job) ==# 'run'
		call job_stop(s:client_job)
	endif

	if exists('b:ctype_lasterror') &&
				\ b:ctype_lasterror != 0 && exists('b:ctype_lastmodified') &&
				\ system('stat -c %Y ' . fnameescape(bufname('%'))) ==
				\ b:ctype_lastmodified	
		return
	endif

	let [lnum, colnum] = getcurpos()[1:2]
	let cmd = fnameescape(s:client_path) . ' ' .
				\ fnameescape(g:ctype_socket_file) . ' ' .
				\ fnameescape(bufname('%')) . ' ' .
				\ lnum . ' ' .
				\ colnum . ' ' .
				\ '"' . g:ctype_client_clangcmdargs . '"'
	let s:client_job = job_start(cmd,
				\ {'out_cb': a:callback,
				\ 'exit_cb': function('s:ClientExit')})
endfunc
