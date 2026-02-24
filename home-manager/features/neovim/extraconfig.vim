set autoindent

let s:jetpackfile = stdpath('data') .. '/site/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim'
let s:jetpackurl = "https://raw.githubusercontent.com/tani/vim-jetpack/master/plugin/jetpack.vim"
if !filereadable(s:jetpackfile)
  call system(printf('curl -fsSLo %s --create-dirs %s', s:jetpackfile, s:jetpackurl))
endif

packadd vim-jetpack
call jetpack#begin()
Jetpack 'tani/vim-jetpack', {'opt': 1} "bootstrap
Jetpack 'junegunn/fzf.vim'
Jetpack 'vim-denops/denops.vim'
Jetpack 'vim-denops/denops-helloworld.vim'
Jetpack 'vim-skk/skkeleton'
Jetpack 'kei-s16/skkeleton-azik-kanatable'
Jetpack 'yasunori0418/statusline_skk.vim'
Jetpack 'itchyny/lightline.vim'
Jetpack 'prabirshrestha/vim-lsp'
Jetpack 'mattn/vim-lsp-settings'
Jetpack 'ctrlpvim/ctrlp.vim'
Jetpack 'nvim-lua/plenary.nvim'
Jetpack 'nvim-telescope/telescope.nvim'
Jetpack 'liquidz/elin'
call jetpack#end()

for name in jetpack#names()
  if !jetpack#tap(name)
    call jetpack#sync()
    break
  endif
endfor

"skkeleton
call skkeleton#azik#add_table('us')
call skkeleton#config(
  \ {
  \   'globalDictionaries': ['~/.skk/SKK-JISYO.L'],
  \   'kanaTable': 'azik',
  \   'eggLikeNewline': v:true
  \ })

imap <C-j> <Plug>(skkeleton-enable)
cmap <C-j> <Plug>(skkeleton-enable)
imap <C-l> <Plug>(skkeleton-disable)
cmap <C-l> <Plug>(skkeleton-disable)

"statusline_skk
let g:lightline = {
  \ 'active': {
  \   'left': [ [ 'mode', 'paste', 'skk_mode' ],
  \             [ 'readonly', 'filename', 'modified' ] ]
  \   },
  \ 'component_function': {
  \   'skk_mode': 'statusline_skk#mode',
  \   },
  \ }

"lightline
set laststatus=2

"telescope
nnoremap <leader>ff <cmd>Telescope find_files<cr>
nnoremap <leader>fg <cmd>Telescope live_grep<cr>
nnoremap <leader>fb <cmd>Telescope buffers<cr>
nnoremap <leader>fh <cmd>Telescope help_tags<cr>

"elin
let g:elin_enable_default_key_mappings = v:true
