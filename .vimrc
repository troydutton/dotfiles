" >>> Line Numbers >>>
set number
set relativenumber
" <<< Line Numbers <<<

" >>> Cursor Shape >>>
let &t_EI = "\<Esc>[1 q"
let &t_SI = "\<Esc>[5 q"
let &t_SR = "\<Esc>[3 q"
" <<< Cursor Shape <<<

" >>> Comment/Uncomment (Ctrl+/) >>>
xnoremap <silent> <C-_> :call ToggleComment()<CR>gv

function! ToggleComment() range
  " Check the first line of the selection to determine the action
  let l:first_line = getline(a:firstline)
  
  if l:first_line =~ '^\s*#'
    " Uncomment: Remove the leading '#' and up to one trailing space
    silent execute a:firstline . ',' . a:lastline . 's/^\(\s*\)#\s\?/\1/e'
  else
    " Comment: Insert '# ' right after any leading whitespace
    silent execute a:firstline . ',' . a:lastline . 's/^\(\s*\)/\1# /e'
  endif
endfunction
" <<< Comment/Uncomment (Ctrl+/) <<<

" >>> Syntax Highlighting >>>
syntax on
filetype plugin indent on
" <<< Syntax Highlighting <<<

" >>> Theme >>>
set termguicolors
set background=dark
colorscheme slate
" <<< Theme <<<
