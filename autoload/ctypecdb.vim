" This file is part of vim-ctype plugin
"
let s:plugin_path = expand('<sfile>:p:h')
let s:clangcdb_path = s:plugin_path . '/../bin/ctype/cdb'
let s:clangcdb_name = 'cdb'

func s:LoadEmptyCompileCommand(bufnum, filename)
	let g:ctype_cdb[a:bufnum] = {}
	let g:ctype_cdb[a:bufnum].filename = fnamemodify(a:filename, ':t')
	let g:ctype_cdb[a:bufnum].workingdir = fnamemodify(a:filename, ':p:h')
	let g:ctype_cdb[a:bufnum].cmdargs = ''
endfunc

func s:ChooseCompileCommand(chid)
	let chn = a:chid
	let bufnum = g:ctype_chan_cdb[chn].bufnr
	let filename = g:ctype_chan_cdb[chn].filename

"	" Clear current command line messages
"	echon "\r\r"
"	echon ''
"	" Redraw the screen
"	redraw

	" Vim doesn't show echo[m] messages on some autocmd events
	" so put it all in input command
	let echs = 'Results of search of'
	if g:ctype_cdb_method == 1 || g:ctype_cdb_method == 2
		let echs .= ' valid'
	endif
	let echs .= ' compile commands for file "' .
				\ filename . '"' . "\n"
	
	let cmds = []
	let cmdn = -1
	for cdb in g:ctype_chan_cdb[chn].cdbs
		let echs .= '=== Compilation Database in ' . cdb.path .' directory contains'
		if g:ctype_cdb_method == 2 || g:ctype_cdb_method == 4
			let echs .= ' ' . cdb.comnum
		endif
		if g:ctype_cdb_method == 1 || g:ctype_cdb_method == 2
			let echs .= ' valid'
		endif
		let echs .= ' compile command'
		if g:ctype_cdb_method == 2 || g:ctype_cdb_method == 4
			let echs .= 's'
		endif
		let echs .= ':' . "\n"
		for cmd in cdb.commands
			call add(cmds, cmd)
			let echs .=  '--- Command #' . len(cmds) . "\n"
			let echs .= 'Filename: ' . cmd.filename . "\n"
			let echs .= 'Working directory: ' . cmd.workingdir . "\n"
			let echs .= 'Command line arguments: ' . cmd.cmdargs . "\n"
			let echs .=  '---' . "\n"
		endfor
		let echs .= '===' . "\n"
	endfor

	let echs .= 'Choose compile command (number) or press ENTER to continue: '
	if !g:ctype_cdb_autoload
		let chosen_cmd = input(echs)
	else
		let chosen_cmd = ''
	endif
	
	if chosen_cmd !=# ''
		try
			let cmdn = str2nr(chosen_cmd)
		catch
			echoerr 'Incorrect command number: ' . chosen_cmd
			let cmdn = -1
		endtry
		if cmdn < 1 || cmdn > len(cmds)
			echoerr 'Incorrect command number: ' . chosen_cmd
			let cmdn = -1
		endif
	endif

	if cmdn != -1
		let g:ctype_cdb[bufnum] = deepcopy(cmds[cmdn - 1])
	elseif len(cmds) != 0
		" Load first command
		let g:ctype_cdb[bufnum] = deepcopy(cmds[0])
	else 
		call s:LoadEmptyCompileCommand(bufnum, filename)
	endif
endfunc

func s:ChooseCC_OnEvent(chid)
	call s:ChooseCompileCommand(a:chid)
	exe 'augroup ctype-cdb-choosecc-' . a:chid
		au!
	augroup END
	let g:ctype_updtu[g:ctype_chan_cdb[a:chid].bufnr] = 1
	call remove(g:ctype_chan_cdb, a:chid)
	call g:CTypeResetType()
endfunc

func s:CDB_Response(chan, msg)
	let chn = ch_info(a:chan).id
	let cdb = g:ctype_chan_cdb[chn].cur_cdb

	if g:ctype_chan_cdb[chn].receive_count == 1
		" Receive cdb path
		call add(g:ctype_chan_cdb[chn].cdbs, {'path': a:msg})
		let g:ctype_chan_cdb[chn].receive_count += 1
	else
		if g:ctype_chan_cdb[chn].receive_count == 2
			" Receive number of commands
			let g:ctype_chan_cdb[chn].cdbs[cdb].comnum = a:msg
			let g:ctype_chan_cdb[chn].cdbs[cdb].commands = []
			let g:ctype_chan_cdb[chn].cdbs[cdb].cur_com = 0
			let g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count = 1
			let g:ctype_chan_cdb[chn].receive_count += 1
		else
			let cur_com = g:ctype_chan_cdb[chn].cdbs[cdb].cur_com
			" Receive commands
			if g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count == 1
				call add(g:ctype_chan_cdb[chn].cdbs[cdb].commands, {'filename': a:msg})
			elseif g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count == 2
				let g:ctype_chan_cdb[chn].cdbs[cdb].commands[cur_com].workingdir = a:msg
			elseif g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count == 3
				let g:ctype_chan_cdb[chn].cdbs[cdb].commands[cur_com].cmdargs = a:msg
				let g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count = 0
				let g:ctype_chan_cdb[chn].cdbs[cdb].cur_com += 1
			endif
			let g:ctype_chan_cdb[chn].cdbs[cdb].com_entr_count += 1
			let g:ctype_chan_cdb[chn].receive_count += 1
		endif

		if g:ctype_chan_cdb[chn].receive_count >
					\ g:ctype_chan_cdb[chn].cdbs[cdb].comnum * 3 + 2
			" Will receive next cdb
			let g:ctype_chan_cdb[chn].receive_count = 1
			let g:ctype_chan_cdb[chn].cur_cdb += 1
		endif
	endif
endfunc

" This callback executes last (but can be before exit callback)
func s:ClangCDB_Close(chan)
	" Wait until exit callback finish
	let timeout = 1000
	let sleeptime = 10
	let elapsedtime = 0
	while job_status(ch_getjob(a:chan)) ==# 'run' && elapsedtime <= timeout
		exe 'sleep ' . sleeptime . ' m'
		let elapsedtime += sleeptime
	endwhile

	let chid = ch_info(a:chan).id

	if g:ctype_chan_cdb[chid].complete 
		" Make choose of compile command synchronous
		exe 'augroup ctype-cdb-choosecc-' . chid
			au!
"			exe 'au CursorMoved,CursorMovedI,CursorHold,CursorHoldI' .
			exe 'au User' .
						\ ' *.c,*.cpp call s:ChooseCC_OnEvent(' . chid . ')'
		augroup END
		exe 'do ctype-cdb-choosecc-' . chid . ' User stub.c'
	else
		call s:LoadEmptyCompileCommand(g:ctype_chan_cdb[chid].bufnr,
					\ g:ctype_chan_cdb[chid].filename)
		let g:ctype_updtu[g:ctype_chan_cdb[chid].bufnr] = 1
		call remove(g:ctype_chan_cdb, chid)
		call g:CTypeResetType()
	endif
endfunc

func s:ClangCDB_Exit(job, exit_status)
	let chid = ch_info(job_getchannel(a:job)).id

	if a:exit_status == 0
		let g:ctype_chan_cdb[chid].complete = 1
		return
	endif
	
	if g:ctype_cdb_showerrormsg
		if a:exit_status == 1
			echoerr g:ctype_prefixname . s:clangcdb_name . ': not enough arguments'
		elseif a:exit_status == 2
			echoerr g:ctype_prefixname . s:clangcdb_name . ': wrong method'
		elseif a:exit_status == 3
			echom g:ctype_prefixname . s:clangcdb_name . ": can't get source file path"
		elseif a:exit_status == 4
			echoerr g:ctype_prefixname . s:clangcdb_name . ': memory allocation error'
		elseif a:exit_status == 8
			echoerr g:ctype_prefixname . s:clangcdb_name . ': fork error'
		elseif a:exit_status == 9
			echom g:ctype_prefixname . s:clangcdb_name . ': no Compilation Database found for "' .
						\ g:ctype_chan_cdb[chid].filename . '" file'
		endif
		if a:exit_status != 3 && a:exit_status != 9
			echoerr 'for source file "' . g:ctype_chan_cdb[chid].filename .
						\ '" ' . g:ctype_prefixname . s:clangcdb_name . ' exited with code = ' . a:exit_status
		endif
	endif
endfunc

func ctypecdb#GetCDB_Entries(bufnr, filename)
	let cmd = fnameescape(s:clangcdb_path) . ' ' .
				\ fnameescape(a:filename) .
				\ ' ' . g:ctype_cdb_method
	let job = job_start(cmd,
				\ {'out_cb': function('s:CDB_Response'),
				\ 'close_cb': function('s:ClangCDB_Close'),
				\ 'exit_cb': function('s:ClangCDB_Exit')})
	let g:ctype_chan_cdb[ch_info(job_getchannel(job)).id] =
				\ {'bufnr': a:bufnr, 'filename': a:filename, 'receive_count': 1,
				\ 'cur_cdb': 0, 'cdbs': [], 'complete': 0}
endfunc
