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
if &term =~# '^\%(tmux\|screen\)'
  let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
endif
set termguicolors
set background=dark
colorscheme slate
" <<< Theme <<<

" >>> Search >>>
set incsearch
set hlsearch
set ignorecase
set smartcase
set shortmess-=S
" <<< Search <<<

" >>> Status Line >>>
set laststatus=2
set statusline=%f\ %m%r%=%y\ line\ %l/%L\ col\ %c\ (%p%%)
" <<< Status Line <<<
