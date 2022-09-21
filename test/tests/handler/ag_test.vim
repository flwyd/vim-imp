call themis#helper('command')
let s:expect = themis#helper('expect')
let s:suite = themis#suite('imp#handler#ag')

source <sfile>:h/_bzl_suggest_base.vim
call BzlSuggestTests(s:suite, 'imp#handler#ag#Suggest')
call BzlMultiLineTests(s:suite, 'imp#handler#ag#Suggest')
source <sfile>:h/_es6_suggest_base.vim
call Es6SuggestTests(s:suite, 'imp#handler#ag#Suggest')
call Es6MultiLineTests(s:suite, 'imp#handler#ag#Suggest')
source <sfile>:h/_java_suggest_base.vim
call JavaSuggestTests(s:suite, 'imp#handler#ag#Suggest')
source <sfile>:h/_kotlin_suggest_base.vim
call KotlinSuggestTests(s:suite, 'imp#handler#ag#Suggest')
source <sfile>:h/_python_suggest_base.vim
call PythonSuggestTests(s:suite, 'imp#handler#ag#Suggest')

function s:suite.before_each() abort
  if !imp#handler#ag#IsAvailable(imp#NewContext())
    Skip 'ag is not available'
  endif
  " Look one level up, in the test/fixtures dir
  Glaive imp Location[default]=parent parent[levels]=1
  " start with no buffers
  %bwipe!
endfunction

function s:suite.after_each() abort
  " get rid of all buffer changes
  %bwipe!
endfunction

function s:suite.no_filetype() abort
  let l:found = imp#handler#ag#Suggest(imp#NewContext(), 'List')
  call s:expect(l:found).to_be_empty()
endfunction

function s:suite.unsupported_filetype() abort
  exec 'edit' FixturePath('empty.pdf')
  let l:found = imp#handler#ag#Suggest(imp#NewContext(), 'List')
  call s:expect(l:found).to_be_empty()
endfunction