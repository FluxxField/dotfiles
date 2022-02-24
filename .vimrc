" show line number
set number

" No error audio
set noerrorbells

set nocompatible
filetype off

" allow backspacing over everything in insert mode
" on some system backspace or delete keys don't work
set backspace=indent,eol,start

" show the cursor position
set ruler

" You will have a bad experience for diagnostic messages when it's default 4000.
set updatetime=300
set lazyredraw

" show relative numbers
set relativenumber

" update vim after file update from outside
set autoread

" clipboard
set clipboard=unnamed

" ignore annoying swapfile messages
set shortmess+=A

" no swap files
set noswapfile
set nobackup
set nowritebackup
set nowb

" persistent undo
" keep undo history across sessions, by storing in file
if has('persistend_undo')
	silent !mkdir ~/.vim/backups > /dev/null 2>&1
	set undodir=~/.vim/backups
	set undofile
endif

" indentation
set autoindent
set smarttab
set shiftwidth=2
set softtabstop=2
set tabstop=2

" always use spaces instead of tabs
set expandtab

" better search
set hlsearch
set incsearch

" ignore case in search
set ignorecase
set smartcase

" don't wrap lines
set nowrap

" automatically :write before running commands
set autowrite

" reduce command timeout for faster escape and 0
set timeoutlen=1000 ttimeoutlen=0

" jump to first non-blank character
set nostartofline

" hightlight matching brackets
set showmatch

" start scrolling when we are 8 lines away from borders
set scrolloff=8
set sidescrolloff=15
set sidescroll=5

" disable mouse scrolling
set mouse=a

" always show column for errors on the left
set signcolumn=yes

" Reference chart of values:
" Ps = 0 -> blinking block
" Ps = 1 -> blinking block (default)
" Ps = 2 -> steady block
" Ps = 3 -> blinking underline
" Ps = 4 -> steady underline
" Ps = 5 -> blinking bar (xterm)
" Ps = 6 -> steady bar (xterm)
let &t_SI = "\e[6 q"
let &t_EI = "\e[6 q"

" Ths makes vim aact like all other editors, buffers can exist in the
" background without being in a window.
set hidden

" allows to use gui colors in terminal
set t_Co=256
"set terminal=screen-256color

" set the background theme to dark
set background="dark"

" Add the g flag to search/replace by default
set gdefault

" set faster redrawing
set ttyfast

set shell=$SHELL

" Vimdiff should always be vertical
set diffopt+=vertical

set nocompatible
set encoding=utf-8

" enable syntax highlighting
syntax on

" install vim-plug if it does not exist
let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.config/nvim/plugged')
Plug 'tpope/vim-sensible'

" airline
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
let g:airline_theme='onedark'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
Plug 'neovim/nvim-lspconfig'

" transparent bg
Plug 'tribela/vim-transparent'

" easier JSC
Plug 'mattn/emmet-vim'
let g:user_emmet_leader_key='<Tab>'

Plug 'prettier/vim-prettier'

" syntax checking
Plug 'dense-analysis/ale'
let g:ale_fixers = { 'javascript': ['eslint'] }
let g:ale_fix_on_save=1
let g:ale_sign_error = '❌'
let g:ale_sign_warning = '⚠️'

" Autoformatting
Plug 'skywind3000/asyncrun.vim'
autocmd BufWritePost *.js AsyncRun -post=checktime ./node_modules/.bin/eslint --fix %

" syntax highlighting for .jsx
Plug 'mxw/vim-jsx'

" syntax ghtlighting for .js
Plug 'pangloss/vim-javascript'

" Show indentation
Plug 'Yggdroot/indentline'

" Highlight yank for a second
Plug 'machakann/vim-highlightedyank'

" Show list of merge conflicts
Plug 'wincent/vcs-jump'

" Configuring NerdTree
Plug 'scrooloose/nerdtree'   
" to hide unwanted files
let NERDTreeIgnore = [ '__pycache__', '\.pyc$', '\.o$', '\.swp',  '*\.swp',  'node_modules/' ]
" show hidden files
let NERDTreeShowHidden=1
let NERDTreeQuitOnOpen=1
let NERDTreeMinimalUI=1
let NERDTreeDirArrows=1
autocmd bufenter * if (winnr("$")) == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary" | q | endif
autocmd StdinReadPre * let s:std_in=1
autocmd vimenter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
"

" Configuring YouCompleteMe
Plug 'valloric/youcompleteme', { 'do': './install.py' }
" youcompleteme configuration
let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py' 
" compatibility with another plugin (ultisnips) 
let g:ycm_key_list_select_completion = [ '<C-n>', '<Down>' ] 
let g:ycm_key_list_previous_completion = [ '<C-p>', '<Up>' ]
let g:SuperTabDefaultCompletionType = '<C-n>'
" disable preview window 
set completeopt-=preview
" navigating to the definition of a a symbol
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

" Configuring CtrlP
Plug 'ctrlpvim/ctrlp.vim'

" Configuring UltiSnips
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" Git integration
" git commands within vim
Plug 'tpope/vim-fugitive'
" git changes on the gutter
Plug 'airblade/vim-gitgutter'
" nerdtree git changes
Plug 'Xuyuanp/nerdtree-git-plugin'

" Autopairs
" closing XML tags
Plug 'jiangmiao/auto-pairs'
" closing braces and brackets
Plug 'alvan/vim-closetag'
" files on which to activate tags auto-closing
let g:closetag_filenames = '*.html,*.xhtml,*.xml,*.vue,*.phtml,*.js,*.jsx,*.coffee,*.erb'

" TMux - Vim intergration
Plug 'christoomey/vim-tmux-navigator'

" Color-scheme
Plug 'joshdick/onedark.vim'
call plug#end()

colorscheme onedark

let mapleader = " "

nnoremap <leader>h :wincmd h<CR>
nnoremap <leader><Tab>n :tabprevious<CR>
nnoremap <leader><Tab>o :tabnext<CR>
nnoremap <leader><Tab>u :tabnew<CR>
nnoremap <leader><Tab>e :tabclose<CR>

" Nerdtree
nnoremap <leader>q :NERDTreeToggle<CR>

" YCM
nnoremap <silent> <Leader>gd :YcmCompleter GoTo<CR>
nnoremap <silent> <Leader>gf :YcmCompleter FixIt<CR>

" telescope
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<CR>
"nnoremap <leader>f <cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown({ previewer = false }))<CR>
nnoremap <leader>fw <cmd>lua require('telescope.builtin').live_grep()<CR>
