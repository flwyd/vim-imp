let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Suggest imports for the symbol under (or next to) the cursor. If you select
" one of the suggested imports, it will be inserted. See |:ImpSuggest|
noremap <Plug>(imp-suggest-current) :ImpSuggest<CR>
if has('patch-8.2.1978')
  inoremap <Plug>(imp-suggest-current) <Cmd>:ImpSuggest<CR>
else
  inoremap <Plug>(imp-suggest-current) <C-\><C-O>:ImpSuggest<CR>
endif

""
" Queries suggested imports for the symbol under (or next to) the cursor.
" Picks the first suggestion and inserts it. See |:ImpFirst|
noremap <Plug>(imp-first-current) :ImpFirst<CR>
if has('patch-8.2.1978')
  inoremap <Plug>(imp-first-current) <Cmd>:ImpFirst<CR>
else
  inoremap <Plug>(imp-first-current) <C-\><C-O>:ImpFirst<CR>
endif
