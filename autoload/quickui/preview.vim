"======================================================================
"
" preview.vim - 
"
" Created by skywind on 2020/01/11
" Last Modified: 2020/01/11 11:30:20
"
"======================================================================

" vim: set noet fenc=utf-8 ff=unix sts=4 sw=4 ts=4 :


"----------------------------------------------------------------------
" private object
"----------------------------------------------------------------------
let s:private = {'winid': -1, 'background': -1, 'state':0}


"----------------------------------------------------------------------
" position to a proper location
"----------------------------------------------------------------------
function! s:around_cursor(width, height)
	let cursor_pos = quickui#core#cursor_pos()
	let row = cursor_pos[0] - a:height 
	let col = cursor_pos[1] + 1
	if quickui#core#in_screen(row, col, a:width, a:height)
		return [row, col]
	endif
	if col + a:width - 1 > &columns
		let col = col - (1 + a:width)
		if quickui#core#in_screen(row, col, a:width, a:height)
			return [row, col]
		endif
	endif
	if row < 1
		let row = row + (1 + a:height)
		if quickui#core#in_screen(row, col, a:width, a:height)
			return [row, col]
		endif
	endif
	if cursor_pos[0] - a:height - 2 < 1
		let row = cursor_pos[0] + 1
	else
		let row = cursor_pos[0] - a:height 
	endif
	if cursor_pos[1] + a:width + 2 < &columns
		let col = cursor_pos[1] + 1
	else
		let col = cursor_pos[1] - a:width
	endif
	return quickui#core#screen_fit(row, col, a:width, a:height)
endfunc


"----------------------------------------------------------------------
" create preview window
"----------------------------------------------------------------------
function! quickui#preview#display(filename, cursor, opts)
	call quickui#preview#close()
	if !filereadable(a:filename)
		call quickui#utils#errmsg('E212: Can not open file: '. a:filename)
		return -1
	endif
	let s:private.state = 0
	silent let bid = bufadd(a:filename)
	silent call bufload(bid)
	let winid = -1
	let title = has_key(a:opts, 'title')? (' ' . a:opts.title .' ') : ''
	let w = get(a:opts, 'w', -1)
	let h = get(a:opts, 'h', -1)
	let w = (w < 0)? 50 : w
	let h = (h < 0)? 10 : h
	let border = get(a:opts, 'border', g:quickui#style#border)
	let button = (get(a:opts, 'close', '') == 'button')? 1 : 0
	let color = get(a:opts, 'color', 'QuickPreview')
	let p = s:around_cursor(w + (border? 2 : 0), h + (border? 2 : 0))
	if has('nvim') == 0
		let winid = popup_create(bid, {'wrap':1, 'mapping':0, 'hidden':1})
		let opts = {'maxwidth':w, 'maxheight':h, 'minwidth':w, 'minheight':h}
		call popup_move(winid, opts)
		let opts = {'close':'button', 'title':title}
		let opts.border = border? [1,1,1,1,1,1,1,1,1] : repeat([0], 9)
		let opts.resize = 0
		let opts.highlight = color
		let opts.borderchars = quickui#core#border_vim(border)
		if get(a:opts, 'persist', 0) == 0
			let opts.moved = 'any'
		endif
		let opts.drag = 1
		let opts.line = p[0]
		let opts.col = p[1]
		let opts.callback = 'quickui#preview#callback'
		" let opts.fixed = 'true'
		call popup_setoptions(winid, opts)
		let s:private.winid = winid
		call popup_show(winid)
	else
		let opts = {'focusable':0, 'style':'minimal', 'relative':'editor'}
		let opts.width = w
		let opts.height = h
		let opts.row = p[0]
		let opts.col = p[1]
		let winid = nvim_open_win(bid, 0, opts)
		let s:private.winid = winid
		let high = 'Normal:'.color.',NonText:'.color.',EndOfBuffer:'.color
		call nvim_win_set_option(winid, 'winhl', high)
		let s:private.background = -1
		if border > 0 && get(g:, 'quickui_nvim_simulate_border', 1) != 0
			let back = quickui#utils#make_border(w, h, border, title, button)
			let nbid = quickui#core#neovim_buffer('previewborder', back)
			let op = {'relative':'editor', 'focusable':0, 'style':'minimal'}
			let op.width = w + 2
			let op.height = h + 2
			let pos = nvim_win_get_config(winid)
			let op.row = pos.row - 1
			let op.col = pos.col - 1
			let background = nvim_open_win(nbid, 0, op)
			call nvim_win_set_option(background, 'winhl', 'Normal:'. color)
			let s:private.background = background
		endif
	endif
	let cmdlist = ['setlocal signcolumn=no norelativenumber']
	if get(a:opts, 'number', 1) == 0
		let cmdlist += ['setlocal nonumber']
	else
		let cmdlist += ['setlocal number']
	endif
	if a:cursor > 0
		let cmdlist += ['normal! gg' . a:cursor . 'Gzz']
	endif
	if has_key(a:opts, 'syntax')
		let cmdlist += ['set ft=' . fnameescape(a:opts.syntax) ]
	endif
	call setbufvar(winbufnr(winid), '__quickui_cursor__', a:cursor)
	call quickui#core#win_execute(winid, cmdlist)
	call quickui#utils#update_cursor(winid)
	let s:private.state = 1
	if has('nvim')
		if get(a:opts, 'persist', 0) == 0
			autocmd CursorMoved * ++once call s:nvim_autocmd()
		endif
	endif
	return winid
endfunc


"----------------------------------------------------------------------
" exit callback
"----------------------------------------------------------------------
function! quickui#preview#callback(winid, code)
	if has('nvim') == 0
		let s:private.winid = -1
	endif
	let s:private.state = 0
endfunc


"----------------------------------------------------------------------
" close window
"----------------------------------------------------------------------
function! quickui#preview#close()
	if s:private.winid >= 0
		if has('nvim') == 0
			call popup_close(s:private.winid, 0)
			let s:private.winid = -1
		else
			call nvim_win_close(s:private.winid, 0)
			let s:private.winid = -1
			if s:private.background >= 0
				call nvim_win_close(s:private.background, 0)
				let s:private.background = -1
			endif
		endif
	endif
	let s:private.state = 0
endfunc


"----------------------------------------------------------------------
" return state
"----------------------------------------------------------------------
function! quickui#preview#visible()
	return s:private.state
endfunc


"----------------------------------------------------------------------
" quit
"----------------------------------------------------------------------
function! s:nvim_autocmd()
	if s:private.state != 0
		if s:private.winid >= 0
			call quickui#preview#close()
		endif
	endif
endfunc


"----------------------------------------------------------------------
" preview file
"----------------------------------------------------------------------
function! quickui#preview#open(filename, ...)
	if !filereadable(a:filename)
		call quickui#utils#errmsg('E484: Cannot open file ' . a:filename)
		return -1
	endif
	let lnum = (a:0 >= 1)? a:1 : -1
	let display_num = g:quickui#style#preview_number
	let opts = {}
	let opts.w = get(g:, 'quickui_preview_w', g:quickui#style#preview_w)
	let opts.h = get(g:, 'quickui_preview_h', g:quickui#style#preview_h)
	let opts.number = get(g:, 'quickui_preview_num', display_num)
	let name = fnamemodify(a:filename, ':p:t')
	let opts.title = 'Preview: ' . name
	let opts.persist = (a:0 >= 2)? a:2 : 0
	return quickui#preview#display(a:filename, lnum, opts)
endfunc




