let s:suite = themis#suite(':ImpFirst')

function s:suite.before() abort
  Glaive imp Suggest[text]=known Insert[text]=top
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
  ImpFirst missing
  call assert_equal(1, line('$'), 'expected just one line')
  call assert_equal('', getline(1), 'expected empty buffer')
endfunction

function s:suite.only_match() abort
  ImpFirst single
  call assert_equal('Import single!', getline(1))
endfunction

function s:suite.first_of_multiple_matches() abort
  ImpFirst multiple
  call assert_equal('Import bar.multiple!', getline(1))
endfunction

function s:suite.multiple_command_args() abort
  ImpFirst single missing multiple
  call assert_equal(3, line('$'), 'expected 2 imports and an empty line')
  call assert_equal('Import single!', getline(1))
  call assert_equal('Import bar.multiple!', getline(2))
  call assert_equal('', getline(3), 'expected last line to be empty')
endfunction

function s:suite.no_command_args() abort
  call setline(1, 'The first line')
  call append(1, 'The single line with multiple words')
  call cursor(2, 5)
  ImpFirst
  call assert_equal('Import single!', getline(1))
  call assert_equal('The first line', getline(2))
  call assert_equal('The single line with multiple words', getline(3))
endfunction
