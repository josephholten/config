set nocompatible              " be iMproved, required
filetype off                  " required

set encoding=UTF-8
set guifont=RobotoMono\ Nerd\ Font\ Mono\ 11
set conceallevel=3

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
    Plugin 'VundleVim/Vundle.vim'
    Plugin 'preservim/nerdtree'
    " Plugin 'morhetz/gruvbox'
    Plugin 'agude/vim-eldar'
    Plugin 'vim-airline/vim-airline'
    Plugin 'vim-airline/vim-airline-themes'
    Plugin 'ryanoasis/vim-devicons'
    Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
    Plugin 'tmhedberg/SimpylFold'
    Plugin 'vim-scripts/indentpython.vim'
    Plugin 'Valloric/YouCompleteMe'
    " Plugin 'vim-syntastic/syntastic'
    Plugin 'nvie/vim-flake8'
    Plugin 'itchyny/vim-haskell-indent'
    " Plugin 'neoclide/coc.nvim'
    Plugin 'fladson/vim-kitty'
    Plugin 'vimwiki/vimwiki'
    Plugin 'lervag/vimtex'
    Plugin 'fatih/vim-go'
    Plugin 'cdelledonne/vim-cmake'
    Plugin 'neomake/neomake'
    Plugin 'junegunn/fzf'
    Plugin 'junegunn/fzf.vim'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
filetype plugin indent on    " required
  if has('vim_starting')
    if has('syntax') && !exists('g:syntax_on')
      syntax enable
    end
  end
if exists("g:loaded_webdevicons")
    call webdevicons#refresh()
endif

if has('syntax')
    syntax enable
    silent! colorscheme eldar
endif

" gruvbox settings
" let g:gruvbox_contrast_dark = 'hard'
"set background=dark " darkmode
"autocmd vimenter * ++nested colorscheme gruvbox

" nerdtree

let NERDTreeShowHidden=1
" autocmd VimEnter * NERDTree
" " Start NERDTree, unless a file or session is specified, eg. vim -S session_file.vim.
" autocmd StdinReadPre * let s:std_in=1
" autocmd VimEnter * if argc() == 0 && !exists('s:std_in') && v:this_session == '' | NERDTree | endif
" "" Exit Vim if NERDTree is the only window left.
" autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree()
"     \ quit | endi
" autocmd VimEnter * wincmd p

" air-line
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#buffer_nr_show = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''


" ----------------------------------------------

" CUSTOM SETTINGS
" allows you to deal with multiple unsaved
" buffers simultaneously without resorting
" to misusing tabs


set hidden

syntax on
set t_Co=256

" no gui
set guioptions =
set number relativenumber
set renderoptions=type:directx

" Don't break words when wrapping lines
set linebreak

" make wrapped lines more obvious
let &showbreak="↳ "
set cpoptions+=n

" Highlight the line I'm on
set cursorline
hi clear CursorLine
hi CursorLine cterm=underline

" Highlight matching paired delimiter
set showmatch

" display incomplete commands
set showcmd

" Tabs
set tabstop=4
" always uses spaces instead of tab characters
set expandtab
set autoindent
" size of an "indent"
set shiftwidth=4

" Enable folding
set foldmethod=indent
set foldlevel=99
" Enable folding with the spacebar
nnoremap <C-space> za

" Leader
let mapleader = "ö"
noremap <leader>t :bel term<cr>
noremap <leader>f :Files<cr>
noremap <leader>F :Lines<cr>

"split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

set nrformats+=alpha

"" python indentation
"au BufNewFile,BufRead *.py
"    \ set tabstop=4
"    \ set softtabstop=4
"    \ set shiftwidth=4
"    \ set textwidth=79
"    \ set expandtab
"    \ set autoindent
"    \ set fileformat=unix
"" python unneccessary whitespace
"" au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/
"
"" javascript, html, css indent
"au BufNewFile,BufRead *.js, *.html, *.css
"    \ set tabstop=2
"    \ set softtabstop=2
"    \ set shiftwidth=2

" ycm options
let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

"python with virtualenv support
py3 << EOF
import os
import sys
if 'VIRTUAL_ENV' in os.environ:
  project_base_dir = os.environ['VIRTUAL_ENV']
  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
  execfile(activate_this, dict(__file__=activate_this))
EOF

let g:go_fmt_command = "goimports"    " Run goimports along gofmt on each save
let g:go_auto_type_info = 1           " Automatically get signature/type info for object under cursor
:augroup gogroup
    :au FileType go set fileformat=unix | set nolist
    :au FileType go nnoremap <leader>lr :GoRun<Enter>
    :au FileType go nnoremap <leader>li :GoInstall<Enter>
    :au FileType go nnoremap <leader>lt :GoTest<Enter>
    :au FileType go nnoremap <leader>lb :GoBuild<Enter>
    :au FileType go nnoremap <leader>ld :GoDoc<Enter>
    :au FileType go nnoremap <leader>lD :GoDocBrowser<Enter>
    :au FileType go nnoremap <leader>ll :GoMetaLinter<Enter>
:augroup END

" custom commands
:command! -complete=file -nargs=1 Rpdf :r !pdftotext -nopgbrk <q-args> - |fmt -csw78

" neomake
" call neomake#configure#automake('w', 500)
let g:neomake_open_list = 2

