let s:suite = themis#suite(':ImpSuggest')

function s:suite.before() abort
  Glaive imp Suggest[text]=known Insert[text]=top Pick[text]=inputlist
  call imp#handler#known#Add('text', [
        \ imp#NewImport('single', 'Import single!'),
        \ imp#NewImport('multiple', 'Import foo.multiple!', {'count': 3}),
        \ imp#NewImport('multiple', 'Import bar.multiple!', {'count': 7})])
endfunction

function s:suite.before_each() abort
  " start with no buffers
  %bwipe!
  edit empty.txt
endfunction

function s:suite.after_each() abort
  " get rid of all buffer changes
  %bwipe!
endfunction

function s:suite.no_matches() abort
  ImpSuggest missing
  call ExpectBufferLines().to_equal([''])
endfunction

function s:suite.only_match() abort
  ImpSuggest single
  call ExpectBufferLines().to_equal(['Import single!', ''])
endfunction

function s:suite.pick_from_multiple_matches() abort
  " Pick the second option
  call feedkeys(":ImpSuggest multiple\<CR>2\<CR>", 'tx')
  call ExpectBufferLines().to_equal(['Import foo.multiple!', ''])
endfunction

function s:suite.multiple_command_args() abort
  call feedkeys(":ImpSuggest single missing multiple\<CR>1\<CR>", 'tx')
  call ExpectBufferLines().to_equal(
        \ ['Import single!', 'Import bar.multiple!', ''])
endfunction

function s:suite.no_command_args() abort
  call setline(1, 'The first line')
  call append(1, 'The single line with multiple words')
  call cursor(2, 10)
  ImpSuggest
  call ExpectBufferLines().to_equal([
        \ 'Import single!',
        \ 'The first line',
        \ 'The single line with multiple words'])
  call assert_equal(3, line('.'), 'should have kept line position')
  exec "normal /multiple\<CR>"
  call feedkeys(":ImpSuggest\<CR>2\<CR>", 'tx')
  call ExpectBufferLines().to_equal([
        \ 'Import foo.multiple!',
        \ 'Import single!',
        \ 'The first line',
        \ 'The single line with multiple words'])
  call assert_equal(4, line('.'), 'should have kept line position')
endfunction
