" Copyright 2022 Google LLC
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

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

function s:suite.multiline_add_two_from_elsewhere() abort
  let l:existing = [
        \ "import {Alice} from '@books/wonderland';",
        \ "import * as asterisk from '@characters/punctuation';",
        \ "import {Bob, Carol} from '@neighbors/nextdoor';",
        \ "import {Eve} from '@rsa/examples';",
        \ "import {",
        \ "  Eyes,",
        \ "  Nose,",
        \ "  Mouth,",
        \ "} from 'body/face';",
        \ "import {oil} from 'texas/houston';",
        \ '',
        \ "import * as actions from './actions';",
        \ "import * as names from './names';",
        \ '',
        \ "class Person {",
        \ "  name: string",
        \ "  age: int",
        \ "}"]
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(19)
  let l:context = imp#NewContext()
  let l:hand = 'import {Hand} from "body/arm";'
  call imp#lang#es6#Insert(l:context, [imp#NewImport('Hand', l:hand)])
  call s:expect(getline(14)).to_equal('import {Hand} from "body/arm";')
  call s:expect(line('$')).to_equal(20)
  let l:elbow = 'import {Elbow} from "body/arm";'
  call imp#lang#es6#Insert(l:context, [imp#NewImport('Elbow', l:elbow)])
  call s:expect(getline(14)).to_equal('import {Elbow, Hand} from "body/arm";')
  call s:expect(line('$')).to_equal(20)
endfunction

function s:suite.several_multiline() abort
  let l:existing = [
        \ 'import {Alice} from "wonderland";',
        \ 'import * as stars from "heaven";',
        \ 'import {',
        \ '  Bob,',
        \ '  Carol,',
        \ '  Dan,',
        \ '} from "people";',
        \ 'import * as asterisk from "punctuation";',
        \ 'import {',
        \ '  Eyes,',
        \ '  Nose,',
        \ '  Mouth,',
        \ '} from "face";',
        \ 'import {tea} from "china";']
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(15)
  let l:context = imp#NewContext()
  let l:ears = 'import { Ears } from "face";'
  call imp#lang#es6#Insert(l:context, [imp#NewImport('Ears', l:ears)])
  call s:expect(line('$')).to_equal(11)
  call s:expect(getline(9)).to_equal(
        \ 'import {Ears, Eyes, Mouth, Nose} from "face";')
endfunction
