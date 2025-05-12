set nocompatible
set encoding=UTF-8

" vundle setup
" see :h vundle for more details or wiki for FAQ
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
    Plugin 'VundleVim/Vundle.vim'

    Plugin 'lervag/vimtex'
    Plugin 'junegunn/fzf'
    Plugin 'junegunn/fzf.vim'
call vundle#end()

filetype plugin indent on
syntax on
set background=dark
colorscheme quiet
set hidden
set number relativenumber
set linebreak
let &showbreak="↳ "
set cpoptions+=n
set cursorline
set showmatch
set showcmd
set tabstop=2
set shiftwidth=2
set expandtab
set smartindent
set nrformats+=alpha

autocmd TerminalWinOpen * set nonu norelativenumber

" Leader
map ö <leader>
noremap <leader>t :bel term<cr>
noremap <leader>T :vert rightb term<cr>
command Vter vert rightb ter
noremap <leader>f :GFiles<cr>
noremap <leader>F :Lines<cr>
noremap <leader>v :VimtexTocOpen<cr>

" VimTeX
let g:vimtex_view_method = 'zathura'
let g:vimtex_compiler_method = 'latexmk'
let g:vimtex_compiler_latexmk = {
    \ 'aux_dir' : 'aux',
    \ 'out_dir' : '',
    \ 'callback' : 1,
    \ 'continuous' : 1,
    \ 'executable' : 'latexmk',
    \ 'hooks' : [],
    \ 'options' : [
    \   '-verbose',
    \   '-file-line-error',
    \   '-synctex=1',
    \   '-interaction=nonstopmode',
    \ ],
    \}
let g:vimtex_view_skim_activate = 1

if empty(v:servername) && exists('*remote_startserver')
      call remote_startserver('VIM')
endif

" Define highlight groups
highlight ExtraWhitespace ctermbg=red guibg=red
"highlight FortranMargin ctermbg=green guibg=green

" Set up global whitespace highlighting
match ExtraWhitespace /\s\+$/

" Set up Fortran-specific highlighting without disturbing whitespace highlighting
"augroup fortran_highlight
"  autocmd!
"  autocmd BufEnter *.f let w:fortran_match_id = matchadd('FortranMargin', '\%>72v.\+')
"  autocmd BufLeave *.f if exists('w:fortran_match_id') | call matchdelete(w:fortran_match_id) | endif
"augroup END
