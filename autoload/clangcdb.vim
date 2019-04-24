let s:plugin_path = expand('<sfile>:p:h')
let s:clangcdb_path = s:plugin_path . '/../bin/clang-cdb'
let s:clangcdb_name = 'clang-cdb'

func s:LoadEmptyCompileCommand(bufnum, filename)
	let g:ctype_cdb[a:bufnum] = {}
	let g:ctype_cdb[a:bufnum].filename = fnamemodify(a:filename, ':t')
	let g:ctype_cdb[a:bufnum].workingdir = fnamemodify(a:filename, ':p:h')
	let g:ctype_cdb[a:bufnum].cmdargs = ''
endfunc

func s:ChooseCompileCommand(job)
	let cmds = []
	let chn = ch_info(job_getchannel(a:job)).id
	let bufnum = g:ctype_chan_cdb[chn].bufnr
	let filename = g:ctype_chan_cdb[chn].filename
	let cmdn = -1

	for cdb in g:ctype_chan_cdb[chn].cdbs
		for cmd in cdb.commands
			call add(cmds, cmd)
		endfor
	endfor

"	echom 'Results of search valid compile commands for file "' .
"				\ filename . '"'
"	
"	for cdb in g:ctype_chan_cdb[chn].cdbs
"		echom '=== Compilation Database in ' . cdb.path .' directory contains ' .
"					\ cdb.comnum . ' valid compile commands:'
"		for cmd in cdb.commands
"			call add(cmds, cmd)
"			echom '--- Command #' . len(cmds)
"			echom 'Filename: ' . cmd.filename
"			echom 'Working directory: ' . cmd.workingdir
"			echom 'Command line arguments: ' . cmd.cmdargs
"			echom '---'
"		endfor
"		echom '==='
"	endfor
"
"	let chosen_cmd = input('Choose compile command (number) or press ENTER to continue: ')
"	
"	if chosen_cmd !=# ''
"		try
"			let cmdn = str2nr(chosen_cmd)
"		catch
"			echoerr 'Incorrect command number: ' . chosen_cmd
"			let cmdn = -1
"		endtry
"		if cmdn < 1 || cmdn > len(cmds)
"			echoerr 'Incorrect command number: ' . chosen_cmd
"			let cmdn = -1
"		endif
"	endif

	if cmdn != -1
		let g:ctype_cdb[bufnum] = cmds[cmdn - 1]
	elseif len(cmds) != 0
		" Load first valid command
		let g:ctype_cdb[bufnum] = cmds[0]
	else 
		call s:LoadEmptyCompileCommand(bufnum)
	endif
endfunc

func s:ClangCDB_Exit(job, exit_status)
	let chid = ch_info(job_getchannel(a:job)).id
	if a:exit_status == 0
		call s:ChooseCompileCommand(a:job)
		call remove(g:ctype_chan_cdb, chid)
		return
	endif

	call s:LoadEmptyCompileCommand(g:ctype_chan_cdb[chid].bufnr,
				\ g:ctype_chan_cdb[chid].filename)
	
	if g:ctype_cdb_showerrormsg
		if a:exit_status == 1
			echoerr s:clangcdb_name . ': not enough arguments'
		elseif a:exit_status == 2
			echoerr s:clangcdb_name . ': wrong method'
		elseif a:exit_status == 3
			echoerr s:clangcdb_name . ': memory allocation error'
		elseif a:exit_status == 6
			echoerr s:clangcdb_name . ': fork error'
		elseif a:exit_status == 7
			echom s:clangcdb_name . ': no Compilation Database found for file "' .
						\ g:ctype_chan_cdb[chid].filename . '"'
		endif
		if a:exit_status != 7
			echoerr 'for source file "' . g:ctype_chan_cdb[chid].filename .
						\ '" ' . s:clangcdb_name . ' exited with code = ' . a:exit_status
		endif
	endif

	if exists('g:ctype_chan_cdb[chid]')
		call remove(g:ctype_chan_cdb, chid)
	endif
endfunc

func clangcdb#GetCDB_Entries(bufnr, filename, method, callback)
	let cmd = fnameescape(s:clangcdb_path) . ' ' .
				\ fnameescape(a:filename) .
				\ ' ' . a:method
	let job = job_start(cmd,
				\ {'out_cb': a:callback,
				\ 'exit_cb': function('s:ClangCDB_Exit')})
	let g:ctype_chan_cdb[ch_info(job_getchannel(job)).id] =
				\ {'bufnr': a:bufnr, 'filename': a:filename, 'receive_count': 1,
				\ 'cur_cdb': 0, 'cdbs': []}
endfunc
