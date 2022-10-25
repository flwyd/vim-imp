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

" Kotlin import handlers supporting `import a.b.Cat` and `import a.b.C as xyz`
" but not wildcard imports. See https://kotlinlang.org/docs/packages.html#imports

function! imp#lang#kotlin#Pattern(context, style, symbol) abort
  let l:word = imp#pattern#Escape(a:style, a:symbol)
  if a:style ==# 'vim'
    let l:word .= '\v'
  endif
  let l:prefix = a:style ==# 'vim' ? '\v\C' : ''
  if a:style ==# 'posix_basic'
    let l:patterns = [
          \ printf('^import\s\+\(\(\w|`\)\+\.\)\+%s\s*$', l:word),
          \ printf('^import\s\+\(\(\w|`\)\+\.\)\+[\w`]\+\s+as\s+%s\s*$', l:word)]
  else
    let l:patterns = [
          \ printf('%s^import\s+((\w|`)+\.)+%s\s*$', l:prefix, l:word),
          \ printf('%s^import\s+((\w|`)+\.)+\w+\s+as\s+%s\s*$', l:prefix, l:word)]
  endif
  return {'patterns': l:patterns, 'fileglobs': ['*.kt', '*.kts', '*.ktm'],
        \ 'style': a:style, 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:sym = imp#pattern#Escape('vim', a:symbol) . '\v'
  let l:match = matchlist(a:line,
        \ printf('\v\Cimport\_s+(.+)\_s+as\_s+(%s)', l:sym))
  if !empty(l:match)
    return imp#NewImport(a:symbol, printf('import %s as %s',
          \ substitute(l:match[1], '\v\_s+', '', 'g'), l:match[2]))
  endif
  let l:match = matchlist(a:line, printf('\v\Cimport\_s+(.+%s)', l:sym))
  if !empty(l:match)
    return imp#NewImport(a:symbol,
          \ 'import ' . substitute(l:match[1], '\v\_s+', '', 'g'))
  endif
  return {}
endfunction

function! imp#lang#kotlin#Suggest(context, symbol) abort
  let l:suggest = printf("import .%s\<S-Left>", a:symbol)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#kotlin#Insert(context, imports) abort
  for l:import in a:imports
    let l:position = s:position(l:import)
    if l:position >= 0
      call append(l:position, l:import.statement)
      let a:context.imported += [l:import]
    else
      let a:context.already_imported += [l:import]
    endif
  endfor
  return 1
endfunction

function! s:position(import) abort
  let l:qualified = s:qualifiedIdentifier(a:import.statement)
  let l:last = 0
  let l:importlines = imp#util#FindLines(
        \ '\v\C^import\s+\S+[.`$]\k+',
        \ 1, function('s:matchEndOfImports'))
  for [l:linenum, l:line] in l:importlines
    if l:qualified ==# s:qualifiedIdentifier(l:line)
      " already imported
      return -1
    endif
    if a:import.statement <# l:line
      " found alphabetic position
      return l:linenum - 1
    endif
    let l:last = l:linenum
  endfor
  if l:last == 0
    " no imports yet, insert after package statement
    let l:packagelines = imp#util#FindLines(
          \ '\v\C^package\s+', 1, function('s:matchEndOfImports'))
    if empty(l:packagelines)
      return 0
    endif
    " add a blank line after package statement
    call append(l:packagelines[0][0], '')
    return l:packagelines[0][0] + 1
  endif
  " alphabetically larger than all others, insert after last one
  return l:last
endfunction

function! s:matchEndOfImports(line) abort
  " import declarations can't come after a top-level declaration, but keywords
  " can appear in an import statement like `fun` so don't stop if the line
  " contains 'import'
  return match(a:line, '\v\C<class|object|fun|interface|typealias>') >= 0
        \ && match(a:line, '\v\C<import>') < 0
endfunction

function! s:qualifiedIdentifier(statement) abort
  return substitute(a:statement,
        \ '\v\C.*<import>\s+([.`[:ident:]]+%(\s+as\s+\s+)?).*', '\1', '')
endfunction
