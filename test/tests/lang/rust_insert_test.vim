" Copyright 2026 Trevor Stone
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

let s:expect = themis#helper('expect')
let s:suite = themis#suite('imp#lang#rust#Insert')

function s:suite.before_each() abort
  " start with no buffers
  %bwipe!
  edit empty.rs
endfunction

function s:suite.after_each() abort
  " get rid of all buffer changes
  %bwipe!
endfunction

function s:suite.top_of_empty_file() abort
  call s:expect(line('$')).to_equal(1)
  call s:expect(getline(1)).to_be_empty()
  let l:context = imp#NewContext()
  let l:statement = 'use std::foo;'
  call imp#lang#rust#Insert(l:context, [imp#NewImport('foo', l:statement)])
  call s:expect(s:allLines()).to_equal(['use std::foo;'])
endfunction

function s:suite.multiple_added() abort
  call s:expect(line('$')).to_equal(1)
  call s:expect(getline(1)).to_be_empty()
  let l:context = imp#NewContext()
  let l:one = 'use std::foo;'
  let l:two = 'use crate::stuff::{self, bar};'
  call imp#lang#rust#Insert(l:context,
        \ [imp#NewImport('foo', l:one), imp#NewImport('bar', l:two)])
  " TODO ensure std comes before crate, per StdExternalCrate rustfmt option?
  call s:expect(s:allLines()).to_equal([l:two, l:one])
endfunction

function s:suite.after_last_import() abort
  let l:existing = [
        \ 'use std::foo;',
        \ '// a line comment',
        \ 'use crate::stuff::{self, bar};',
        \ 'fn func() -> u8 { return 42; }',
        \ 'struct Greeting { word: String }']
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(6)
  let l:context = imp#NewContext()
  " Current implementation adds after the last use statement that sorts less
  let l:statement = 'use crate::wheels::foo;'
  call imp#lang#rust#Insert(l:context, [imp#NewImport('foo', l:statement)])
  call s:expect(s:allLines()).to_equal(
        \ l:existing[:2] + [l:statement] + l:existing[3:])
endfunction

function s:suite.merge_with_group() abort
  let l:existing = [
        \ 'use std::foo;',
        \ '// a line comment',
        \ 'use crate::stuff::{self, bar};',
        \ 'fn func() -> u8 { return 42; }',
        \ 'struct Greeting { word: String }']
  call append(0, l:existing)
  call s:expect(line('$')).to_equal(6)
  let l:context = imp#NewContext()
  let l:one = 'use crate::stuff::One;'
  " Current implementation doesn't create new groups
  let l:two = 'use std::foo::Two;'
  call imp#lang#rust#Insert(l:context,
        \ [imp#NewImport('One', l:one), imp#NewImport('Two', l:two)])
  call s:expect(s:allLines()).to_equal(
        \ [l:existing[0], l:two, l:existing[1],
        \ 'use crate::stuff::{self, One, bar};',
        \ l:existing[3], l:existing[4]])
endfunction

function s:suite.merge_with_group_comment() abort
  let l:existing = [
        \ 'use std::foo;',
        \ '// a line comment',
        \ 'use crate::stuff::{Odds, /* Comment */ Ends};',
        \ 'use crate::widgets::Button;',
        \ 'fn func() -> u8 { return 42; }',
        \ 'struct Greeting { word: String }']
  call append(0, l:existing)
  let l:context = imp#NewContext()
  let l:statement = 'use crate::stuff::Things;'
  call imp#lang#rust#Insert(l:context, [imp#NewImport('Things', l:statement)])
  call s:expect(s:allLines()).to_equal(
        \ [l:existing[0], l:existing[1],
        \ 'use crate::stuff::{Odds, /* Comment */ Ends};',
        \ 'use crate::stuff::Things;',
        \ l:existing[3], l:existing[4], l:existing[5]])
endfunction

function s:suite.into_multiline() abort
  let l:existing = [
        \ 'use std::io::{',
        \ '    Write,',
        \ '    stderr,',
        \ '    stdout,',
        \ '};',
        \ 'use std::path::{',
        \ '  Path,',
        \ '  PathBuf,',
        \ '};',
        \ 'fn main() { println!("main squeeze"); }']
  call append(0, l:existing)
  let l:statement = 'use std::io::stdin;'
  call imp#lang#rust#Insert(imp#NewContext(),
        \ [imp#NewImport('stdin', l:statement)])
  " We currently don't preserve line breaks
  call s:expect(s:allLines()).to_equal(
        \ ['use std::io::{Write, stderr, stdin, stdout};']
        \ + l:existing[5:])
endfunction

function s:suite.sort_order() abort
  " using the StdExternalCrate rustfmt order
  let l:existing = [
        \ 'use std::fs::File;',
        \ 'use std::io::Write;',
        \ 'use std::path::Path;',
        \ '',
        \ 'use food::fruit::{Apple, Banana, Cherry, Durian};',
        \ 'use food::meat::Chicken;',
        \ 'use food::meat::Mutton;',
        \ 'use tool::electric::solder::Iron;',
        \ 'use tool::hand::screwdriver::Flathead;',
        \ '',
        \ 'use crate::menu::meat::Hamburger;',
        \ 'use crate::menu::meat::Sausage;',
        \ 'use crate::workspace::Bench;',
        \ 'use crate::workspace::Desk;',
        \ '',
        \ 'pub use crate::image::Logo;',
        \ 'pub use crate::image::Sign;',
        \ '',
        \ 'fn main() { println!("Look at all this stuff!"); }']
  call append(0, l:existing)
  let l:concept = 'use self::concept as I;'
  let l:humor = 'use self::deprecating::Humor;'
  let l:stdio = 'use std::io;'
  let l:stdin = 'use std::io::stdin;'
  let l:pathbuf = 'use std::path::PathBuf;'
  let l:rye = 'use food::bread::Rye;'
  let l:wheat = 'use food::bread::Wheat;'
  let l:beef = 'use food::meat::Beef;'
  let l:pork = 'use food::meat::Pork;'
  let l:casava = 'use food::starch::Casava;'
  let l:potato = 'use food::starch::Potato;'
  let l:hammer = 'use tool::hand::hammer;'
  let l:phillips = 'use tool::hand::screwdriver::Phillips;'
  let l:meme = 'use crate::image::Meme;'
  let l:calamari = 'use crate::menu::appetizer::Calamari;'
  let l:pudding = 'use crate::menu::meat::Pudding;'
  let l:counter = 'use crate::workspace::Counter;'
  let l:elephant = 'use crate::zoo::Elephant;'
  let l:facade = 'pub use crate::image::Facade;'
  let l:fast = 'use velocity::Fast;'
  let l:slow = 'use velocity::Slow;'
  call imp#lang#rust#Insert(imp#NewContext(), [
        \ imp#NewImport('PathBuf', l:pathbuf),
        \ imp#NewImport('io', l:stdio),
        \ imp#NewImport('stdin', l:stdin),
        \ imp#NewImport('Humor', l:humor),
        \ imp#NewImport('I', l:concept),
        \ imp#NewImport('Wheat', l:wheat),
        \ imp#NewImport('Pork', l:pork),
        \ imp#NewImport('Rye', l:rye),
        \ imp#NewImport('Beef', l:beef),
        \ imp#NewImport('Pudding', l:pudding),
        \ imp#NewImport('Potato', l:potato),
        \ imp#NewImport('Casava', l:casava),
        \ imp#NewImport('hammer', l:hammer),
        \ imp#NewImport('Phillips', l:phillips),
        \ imp#NewImport('Counter', l:counter),
        \ imp#NewImport('Meme', l:meme),
        \ imp#NewImport('Calamari', l:calamari),
        \ imp#NewImport('Elephant', l:elephant),
        \ imp#NewImport('Facade', l:facade),
        \ imp#NewImport('Slow', l:slow),
        \ imp#NewImport('Fast', l:fast),
        \ ])
  call s:expect(s:allLines()->join("\n")).to_equal([
        \ 'use self::concept as I;',
        \ 'use self::deprecating::Humor;',
        \ 'use std::fs::File;',
        \ 'use std::io;',
        \ 'use std::io::Write;',
        \ 'use std::io::stdin;',
        \ 'use std::path::Path;',
        \ 'use std::path::PathBuf;',
        \ '',
        \ 'use food::bread::Rye;',
        \ 'use food::bread::Wheat;',
        \ 'use food::fruit::{Apple, Banana, Cherry, Durian};',
        \ 'use food::meat::Beef;',
        \ 'use food::meat::Chicken;',
        \ 'use food::meat::Mutton;',
        \ 'use food::meat::Pork;',
        \ 'use food::starch::Casava;',
        \ 'use food::starch::Potato;',
        \ 'use tool::electric::solder::Iron;',
        \ 'use tool::hand::hammer;',
        \ 'use tool::hand::screwdriver::Flathead;',
        \ 'use tool::hand::screwdriver::Phillips;',
        \ '',
        \ 'use crate::image::Meme;',
        \ 'use crate::menu::appetizer::Calamari;',
        \ 'use crate::menu::meat::Hamburger;',
        \ 'use crate::menu::meat::Pudding;',
        \ 'use crate::menu::meat::Sausage;',
        \ 'use crate::workspace::Bench;',
        \ 'use crate::workspace::Counter;',
        \ 'use crate::workspace::Desk;',
        \ 'use crate::zoo::Elephant;',
        \ 'use velocity::Fast;',
        \ 'use velocity::Slow;',
        \ '',
        \ 'pub use crate::image::Facade;',
        \ 'pub use crate::image::Logo;',
        \ 'pub use crate::image::Sign;',
        \ '',
        \ 'fn main() { println!("Look at all this stuff!"); }'
        \ ]->join("\n"))
endfunction

function! s:allLines() abort
  let l:lines = []
  for l:i in range(1, line('$'))
    let l:line = getline(l:i)
    if !empty(l:line) || l:i < line('$')
      call add(l:lines, l:line)
    endif
  endfor
  return l:lines
endfunction
