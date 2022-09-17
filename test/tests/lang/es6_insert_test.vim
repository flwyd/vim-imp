let s:expect = themis#helper('expect')
let s:suite = themis#suite('imp#lang#es6#Insert')

function s:suite.before_each() abort
  " start with no buffers
  %bwipe!
  edit empty.js
endfunction

function s:suite.after_each() abort
  " get rid of all buffer changes
  %bwipe!
endfunction

function s:suite.top_of_empty_file() abort
  call s:expect(line('$')).to_equal(1)
  call s:expect(getline(1)).to_be_empty()
  let l:context = imp#NewContext()
  let l:statement = 'import foo from "foo-library";'
  call imp#lang#es6#Insert(l:context, [imp#NewImport('foo', l:statement)])
  call s:expect(line('$')).to_equal(2)
  call s:expect(getline(1)).to_equal(l:statement)
  call s:expect(getline(2)).to_be_empty()
endfunction

function s:suite.multiple_added() abort
  call s:expect(line('$')).to_equal(1)
  call s:expect(getline(1)).to_be_empty()
  let l:context = imp#NewContext()
  let l:one = 'import foo from "foo-library";'
  let l:two = 'import { bar } from "@bar-lib";'
  call imp#lang#es6#Insert(l:context,
        \ [imp#NewImport('foo', l:one), imp#NewImport('bar', l:two)])
  call s:expect(line('$')).to_equal(3)
  call s:expect(getline(1)).to_equal(l:one)
  call s:expect(getline(2)).to_equal(l:two)
  call s:expect(getline(3)).to_be_empty()
endfunction

function s:suite.after_last_import() abort
  let l:existing = [
        \ 'import foo from "foo-library";',
        \ '// a line comment',
        \ 'import { bar as baz } from "wherever";',
        \ 'function func() { return 42; }',
        \ 'console.log("import misleading from ''somewhere''");']
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(6)
  let l:context = imp#NewContext()
  let l:statement = 'import { foo } from "somewhere";'
  call imp#lang#es6#Insert(l:context, [imp#NewImport('foo', l:statement)])
  call s:expect(line('$')).to_equal(7)
  call s:expect(getline(4)).to_equal(l:statement)
  call s:expect(getline(5)).to_equal(l:existing[3])
  call s:expect(getline(3)).to_equal(l:existing[2])
endfunction

function s:suite.merge_with_module() abort
  let l:existing = [
        \ 'import foo from "foo-library";',
        \ '// a line comment',
        \ 'import { bar as baz } from "wherever";',
        \ 'function func() { return 42; }',
        \ 'console.log("import misleading from ''somewhere''");']
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(6)
  let l:context = imp#NewContext()
  let l:one = 'import { one } from "wherever";'
  " module merge is successful even though existing uses double quotes
  let l:two = 'import * as two from ''foo-library'';'
  call imp#lang#es6#Insert(l:context,
        \ [imp#NewImport('one', l:one), imp#NewImport('two', l:two)])
  call s:expect(line('$')).to_equal(6)
  " TODO respect internal spacing in braces
  call s:expect(getline(1)).to_equal('import foo, * as two from "foo-library";')
  call s:expect(getline(3)).to_equal('import {bar as baz, one} from "wherever";')
endfunction
