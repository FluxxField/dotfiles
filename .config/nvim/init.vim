syntax on
filetype plugin indent on

call plug#begin('~/.vim/plugged')
" Appearance
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'tribela/vim-transparent'
Plug 'joshdick/onedark.vim'

" Syntax
Plug 'prettier/vim-prettier'
Plug 'dense-analysis/ale'
Plug 'jiangmiao/auto-pairs'
Plug 'alvan/vim-closetag'

" Language specific
Plug 'mxw/vim-jsx'
Plug 'pangloss/vim-javascript'
Plug 'Yggdroot/indentline'
Plug 'machakann/vim-highlightedyank'
Plug 'wincent/vcs-jump'

" NerdTree
Plug 'scrooloose/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'

" YouCompleteMe
Plug 'valloric/youcompleteme', { 'do': './install.py' }

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'Xuyuanp/nerdtree-git-plugin'

" nvim
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'
Plug 'nvim-treesitter/nvim-treesitter', { 'do': ':TSUpdate' }
Plug 'neovim/nvim-lspconfig'

" misc
Plug 'ctrlpvim/ctrlp.vim'
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tpope/vim-sensible'
Plug 'mattn/emmet-vim'
call plug#end()

colorscheme onedark

" DEFAULTS
" appearence
set background=dark   " Tells nvim the background color of the terminal
set title             " Set the title of the window to titlestring
set relativenumber    " Show the line number relative to the current line
set number            " Precede each line with its line number
set nowrap            " Wrap the lines when they are longer then the width of the window
set ruler             " Show the line and column number of cursor position
set noshowmode        " For echodoc to hide -- INSERT -- in command line
set scrolloff=8       " Minimal number of screen lines to keep above and below the cursor
set cursorline        " Highlight the current line where the cursor is
set guicursor         " Set the cursor to the block (fro insert mode)
set cmdheight=1       " Make sure the cmmd height is always one
set laststatus=1      " Keep teh statusbar always on
set showtabline=1     " Show the tabline if at least two tab pages are open
set display+=lastline " Display as much as possible of the last line
set noerrorbells      " Turns off the error ding
set signcolumn=yes    " Show the culumn left to the number line for showing error signs
set splitbelow        " Horizontal split will put the new window below the current
set splitright        " Vertical split will put the new window to the right of the current
set updatetime=100    " Having longer updatetime (default 4s) laeds to noticeable delays
set pyxversion=3      " Specifies the python version for pyx functions (3-python3)
set foldmethod=marker " The kind of folding used for the current window
set backspace=indent,eol,start
let &t_SI="\e[6 q"
let &t_EI="\e[6 q"
set t_Co=256
set gdefault
set ttyfast

" Backup & history
set hidden
set history=1000
set undofile
set undolevels=10000
set undodir=~/.vim/undodir
set nobackup
set nowritebackup
set noswapfile

" Spaces, Tabs & Indent
set tabstop=2
set softtabstop=2
set shiftwidth=2
set smartindent
set autoindent
set expandtab
set smarttab

" search
set incsearch
set nohlsearch
set ignorecase
set smartcase

set viminfo^=%

" REMAPS
let mapleader=" "

" PLUGIN: UltiSnips
let g:UltiSnipsExpandTrigger = '<Tab>'
let g:UltiSnipsJumpForwardTrigger = '<Tab>'
let g:UltiSnipsJumpBackwardTrigger = '<s-Tab>'

" PLUGIN: EmmetVim
let g:user_emmet_leader_key='<Tab>'

" PLUGIN: YouCompleteMe
let g:ycm_global_ycm_extra_conf = '~/.vim/.ycm_extra_conf.py'
let g:ycm_key_list_select_completion = [ '<C-n>', '<Down>' ]
let g:ycm_key_list_previous_completion = [ '<C-p>', '<Up>' ]
let g:SuperTabDefaultCompletionType = '<C-n>'
set completeopt-=preview
map <leader>g : YcmCompleter GoToDefintionElseDeclaration<CR>

" PLUGIN: NERDTree
autocmd bufenter * if (winnr("$")) == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary" | q | endif
autocmd StdinReadPre * let s:std_in=1
autocmd vimenter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" PLUGIN: Ale
let g:closetag_filenames = '*.html,*.xhtml,*.xml,*vue,*.phtml,*.js,*.jsx,*.coffee'
let g:ale_fixers = { 'javascript': ['eslint'] }
let g:ale_fix_on_save=1
let g:ale_sign_error = '❌'
let g:ale_sign_warning = '⚠️ '

" PLUGIN: Airline
let g:airline_theme='onedark'

nnoremap <leader>h :wincmd h<CR>
nnoremap <leader><Tab>n : tabprevious<CR>
nnoremap <leader><Tab>o :tabnext<CR>
nnoremap <leader><Tab>u :tabnew<CR>
nnoremap <leader><Tab>e :tabclose<CR>

" NERDTree
nnoremap <leader>q :NERDTreeToggle<CR>

" YCM
nnoremap <silent> <leader>gd :YcmCompleter GoTo<CR>
nnoremap <silent> <leader>gf :YcmCompleter FixIt<CR>

" telescope
nnoremap <leader>ff <cmd>lua require('telescope.builtin').find_files()<CR>
nnoremap <leader>fw <cmd>lua require('telescope.builtin').live_grep()<CR>

" AUTOCMDS
" Return to the last edit position when opening files
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif

" Ignore files
set wildignore+=**/.git/*
set wildignore+=**/build/*
set wildignore+=**/coverage/*
set wildignore+=**/node_modules/*

lua require('FluxxField')
