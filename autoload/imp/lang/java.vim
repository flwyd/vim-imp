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

" Java import handlers, supports `import a.b.C;` and `import static foo.bar.BAZ;`
" but not wildcard imports.
" See https://docs.oracle.com/javase/tutorial/java/package/usepkgs.html

function! imp#lang#java#Pattern(context, style, symbol) abort
  let l:word = imp#pattern#Escape(a:style, a:symbol)
  if a:style ==# 'vim'
    let l:word .= '\v'
  endif
  let l:prefix = a:style ==# 'vim' ? '\v\C' : ''
  if a:style ==# 'posix_basic'
    let l:patterns = [
          \ printf('^import\s\+\(\w\+\.\)\+%s;', l:word),
          \ printf('^import\s\+static\s\+\(\w\+\.\)\+%s;', l:word)]
  else
    let l:patterns = [
          \ printf('%s^import\s+(\w+\.)+%s;', l:prefix, l:word),
          \ printf('%s^import\s+static\s+(\w+\.)+%s;', l:prefix, l:word)]
  endif
  return {'patterns': l:patterns, 'fileglobs': ['*.java'], 'style': a:style,
        \ 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:sym = imp#pattern#Escape('vim', a:symbol) . '\v'
  let l:match = matchlist(a:line,
        \ printf('\v\Cimport\_s+(static\s+)?(.+%s)', l:sym))
  if empty(l:match)
  return {}
  endif
  let l:static = empty(l:match[1]) ? '' : 'static '
  return imp#NewImport(a:symbol, printf('import %s%s;',
        \ l:static, substitute(l:match[2], '\v\_s+', '', 'g')))
endfunction

function! imp#lang#java#Suggest(context, symbol) abort
  let l:suggest = printf("import%s .%s;\<S-Left>",
        \ s:probablyStatic(a:symbol) ? ' static' : '', a:symbol)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#java#Insert(context, imports) abort
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
  let l:static = s:isStatic(a:import.statement)
  let l:qualified = s:qualifiedIdentifier(a:import.statement)
  let l:first = {'static': 0, 'non': 0}
  let l:last = {'static': 0, 'non': 0}
  let l:importlines = imp#util#FindLines(
        \ '\v\C^import\s+(static\s+)?\S+[.$]\k+;',
        \ 1, function('s:matchEndOfImports'))
  for [l:linenum, l:line] in l:importlines
    if l:qualified ==# s:qualifiedIdentifier(l:line)
      " already imported
      return -1
    endif
    let l:linestatic = s:isStatic(l:line)
    if l:linestatic == l:static && a:import.statement <# l:line
      " found alphabetic position
      return l:linenum - 1
    endif
    let l:key = l:linestatic ? 'static' : 'non'
    let l:last[l:key] = l:linenum
    if l:first[l:key] == 0
      let l:first[l:key] = l:linenum
    endif
  endfor
  if l:first['static'] == 0 && l:first['non'] == 0
    " no imports yet, insert after package statement
    let l:packagelines = imp#util#FindLines(
          \ '\v\C^package\s+', 1, function('s:matchEndOfImports'))
    if empty(l:packagelines)
     return 0
   endif
    " insert blank line between package and first import statement
    call append(l:packagelines[0][0], '')
    return l:packagelines[0][0] + 1
  endif
  if l:static
    " add after last static or before first non-static
    return l:last['static'] > 0 ? l:last['static'] : l:first['non'] - 1
  else
    " add after last non-static, or after last static
    return l:last['non'] > 0 ? l:last['non'] : l:last['static']
  endif
endfunction

function! s:matchEndOfImports(line) abort
  " import declarations can't come once a class has been declared
  return match(a:line, '\v\C<class>') >= 0
endfunction

function! s:isStatic(statement) abort
  return match(a:statement, '\v\C^\s*<import>\s+<static>') >= 0
endfunction

function! s:qualifiedIdentifier(statement) abort
  return substitute(a:statement,
        \ '\v\C.*<import>%(\s+<static>)?\s+([.$[:ident:]]+).*', '\1', '')
endfunction

function! s:probablyStatic(symbol) abort
  " Java conventions: methods are lowerCamel, constants are SHOUTING_SNAKE
  " Single-letter capitals are probably a class like Android's R resources
  return match(a:symbol, '\v\C^[a-z]|^[A-Z_]{2,}$') >= 0
endfunction
