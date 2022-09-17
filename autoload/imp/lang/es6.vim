" Import handling for import statements introduced in ECMAScript 6, see
" https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import
" Merges multiple imports from the same source into a single statement.
" TODO Vim9-script uses the same import syntax, consider extracting behavior.

let s:logger = maktaba#log#Logger('imp#lang#es6')

function! imp#lang#es6#Pattern(context, style, symbol) abort
  if a:style ==# 'posix_basic'
    return {}  " this would be really ugly
  endif
  let l:word = imp#pattern#Escape(a:style, a:symbol)
  if a:style ==# 'vim'
    let l:word .= '\v'
  endif
  let l:prefix = a:style ==# 'vim' ? '\v\C' : ''
  " All ES6 static imports end with `from 'module/name';` or
  " `from "something.js"` at EOL. (Technically comments are allowed too.)
  let l:end = '\s+from\s+("[^"[:space:]]+"|''[^''[:space:]]+'')\s*(;|$)'
  " extra `foo` or `foo as bar` identifiers
  let l:extra = '\s*\w+(\s+as\s+\w+)?\s*'
  let l:patterns = []
  " Pattern examples matching `x`, lots of spacing variants elided
  " (1) import x from 'foo';
  " (2) import * as x from 'foo';
  " (3) import x, * as y from 'foo';
  " (4) import y, * as x from 'foo';
  " (5) import {x} from 'foo';
  " (5) import {a, x, b} from 'foo';
  " (5) import c, {x} from 'foo';
  " (5) import c, {a as z, x, b,} from 'foo';
  " (6) import {a as x} from 'foo';
  " (6) import {a, b as x, c as z} from 'foo';
  " (6) import c, {a as x, b} from 'foo';
  " (7) import x, {a, b, c} from 'foo';
  " (7) import x, {} from 'foo';
  let l:patterns = [
        \ printf('%s^import\s+%s%s', l:prefix, l:word, l:end),
        \ printf('%s^import\s+\*\s+as\s+%s%s', l:prefix, l:word, l:end),
        \ printf('%s^import\s+%s\s*,\s*\*\s+as\s+\w+%s', l:prefix, l:word, l:end),
        \ printf('%s^import\s+\w+\s*,\s*\*\s+as\s+%s%s', l:prefix, l:word, l:end),
        \ printf('%s^import\s+(\w+\s*,\s*)?\{(%s,)*\s*%s(\s*,%s)*,?\s*\}%s',
            \ l:prefix, l:extra, l:word, l:extra, l:end),
        \ printf('%s^import\s+(\w+\s*,\s*)?\{(%s,)*\s*\w+\s+as\s+%s(\s*,%s)*,?\s*\}%s',
            \ l:prefix, l:extra, l:word, l:extra, l:end),
        \ printf('%s^import\s+%s\s*,\s*\{(%s(,%s)*,?)?\s*\}%s',
            \ l:prefix, l:word, l:extra, l:extra, l:end)]
  " multiline because people sometimes line break inside {} section
  return {'patterns': l:patterns, 'style': a:style, 'multiline': 1,
        \ 'fileglobs': ['*.js', '*.jsx', '*.cjs', '*.mjs', '*.ts', '*.tsx'],
        \ 'Parse': function('s:parseImport')}
endfunction

function! s:parseImport(context, symbol, line) abort
  let l:parsed = s:parseStatement(a:line)
  if empty(l:parsed)
    return {}
  endif
  let l:from = l:parsed.fromquote . l:parsed.from . l:parsed.fromquote . ';'
  if a:symbol ==# l:parsed.default.alias ||
        \ (empty(l:parsed.default.alias) && a:symbol ==# l:parsed.default.symbol)
    " import foo from 'bar'; import foo as baz from 'bar';
    return imp#NewImport(a:symbol, printf(
          \ 'import %s from %s', s:identifierToString(l:parsed.default), l:from))
  endif
  if a:symbol ==# l:parsed.namespace.alias
    " import * as foo from 'bar';
    return imp#NewImport(a:symbol, printf(
          \ 'import %s from %s', s:identifierToString(l:parsed.namespace), l:from))
  endif
  for l:name in l:parsed.named
    if a:symbol ==# l:name.alias ||
          \ (empty(l:name.alias) && a:symbol ==# l:name.symbol)
      return imp#NewImport(a:symbol, printf(
            \ 'import {%s} from %s', s:identifierToString(l:name), l:from))
    endif
  endfor
  call s:logger.Debug('Match "%s" does not parse for %s', a:line, a:symbol)
  return {}
endfunction

function! imp#lang#es6#Suggest(context, symbol) abort
  let l:suggest = printf("import {%s} from '';\<Left>\<Left>", a:symbol)
  let l:statement = input(a:symbol . ': ', l:suggest)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction

function! imp#lang#es6#Insert(context, choices) abort
  let l:success = 1
  for l:choice in a:choices
    let l:action = s:insertSymbol(a:context, l:choice)
    if l:action.inserted && l:action.success
      call add(a:context.imported, l:action['import'])
    elseif l:action.success
      call add(a:context.already_imported, l:action['import'])
    endif
    let l:success = l:action.success && l:success
  endfor
  return l:success
endfunction

" TODO This isn't matching with existing imports, add debug logging
function! s:insertSymbol(context, choice) abort
  let l:parsed = s:parseStatement(a:choice.statement)
  if empty(l:parsed)
    call s:logger.Debug('Could not parse choice %s', a:choice.statement)
    return {'inserted': 0, 'success': 0}
  endif
  let l:frompat = '\v\C<from\_s+[''"]'
  let l:lastline = 0
  let l:hanging = 0
  let l:hangingstart = 0
  for l:i in range(1, line('$'))
    if imp#util#IsCommentLine(l:i)
      continue
    endif
    let l:line = getline(l:i)
    if !empty(l:hanging)
      if match(l:line, '\v\C^\s*import>') >= 0
        " didn't finish previous hanging import, but found a new import line
        call s:logger.Debug('Abandoning partial import %s', l:hanging)
        let l:hanging = ''
        let l:hangingstart = 0
      else
        let l:hanging .= "\n" . l:line
        if match(l:hanging, ';') >= 0 || match(l:hanging, l:frompat) >= 0
          call s:logger.Debug('Multi-line import %s', l:hanging)
          let l:line = l:hanging
          let l:hanging = ''
        else
          call s:logger.Debug('Continued partial import %s', l:hanging)
          continue
        endif
      endif
    endif
    if match(l:line, '^\v\C\s*import>') < 0
      call s:logger.Debug('Ignoring line %s', l:line)
      continue
    endif
    if match(l:line, l:frompat) < 0 && match(l:line, ';') < 0
      " incomplete import, maybe part of a multi-line statement
      let l:hanging = l:line
      if l:hangingstart == 0
        let l:hangingstart = l:i
      endif
      call s:logger.Debug('Partial import line %s', l:line)
      continue
    endif
    " line starts with 'import' and has 'from' so try parsing it
    let l:parsedline = s:parseStatement(l:line)
    if empty(l:parsedline)
      call s:logger.Debug('Could not parse line %s', l:line)
      continue
    endif
    if !empty(l:parsedline.dynamic) || !empty(l:parsedline.sideeffect)
      let l:lastline = l:i
      continue
    endif
    if l:parsed.from ==# l:parsedline.from
      let l:merged = s:mergeImport(l:parsedline, l:parsed)
      if l:merged == l:parsedline
        call s:logger.Debug('Already imported %s in %s', a:choice, l:line)
        return {'inserted': 0, 'success': 1, 'import': a:choice}
      endif
      let l:newline = s:importToString(l:merged)
      call s:logger.Debug('Merged %s = %s + %s',
            \ l:newline, a:choice.statement, l:line)
      if l:hangingstart > 0
        " TODO this turns multi-line imports into single line, if that's a
        " problem we could probably guess the line-break strategy and reflow
        call setline(l:hangingstart, l:newline)
        execute printf('%d,%ddelete _', l:hangingstart+1, l:i)
      else
        call setline(l:i, l:newline)
      endif
      return {'inserted': 1, 'success': 1,
            \ 'import': imp#NewImport(a:choice.symbol, l:newline)}
    endif
    let l:lastline = l:i
  endfor
  call s:logger.Debug('Adding after %s because no module match for %s',
        \ l:lastline, a:choice)
  " no imports from this source yet, so add after last import line
  call append(l:lastline, [a:choice.statement])
  return {'inserted': 1, 'success': 1, 'import': a:choice}
endfunction

function! s:parseStatement(statement) abort
  if match(a:statement, '\v\C<import>') < 0
    call s:logger.Debug('No import in %s', a:statement)
    " doesn't have the word 'import' at all
    return {}
  endif
  " from: import ... from 'xyz'; (without quotes)
  " fromquote: single or double quote char around xyz above
  " default: import xyz from 'somewhere';
  " namespace: import * as xyz from 'somewhere';
  " named: import { x, y, z } from 'somewhere';
  " dynamic: const xyz = import('somewhere'); (the whole string)
  " sideeffect: import 'module-just-for-side-effects';
  " trailing: comments or statements after import statement
  let l:parsed = {
        \ 'from': '',
        \ 'fromquote': '',
        \ 'default': s:newIdentifier('', ''),
        \ 'namespace': s:newIdentifier('', ''),
        \ 'named': [],
        \ 'dynamic': '',
        \ 'sideeffect': '',
        \ 'trailing': '',
        \ }
  if match(a:statement, '\v\C<import\s*\(') >= 0
    let l:parsed.dynamic = a:statement
    call s:logger.Debug('Dynamic import: %s', a:statement)
    return l:parsed
  endif
  if match(a:statement, '\v\C<import\s*[''"]') >= 0
    let l:parsed.sideeffect = a:statement
    call s:logger.Debug('Side effect import: %s', a:statement)
    return l:parsed
  endif
  let l:defaultpat = '%((\k+%(\_s+as\_s+\k+)?)\s*,?)?'
  let l:namespacepat = '(\*\_s+as\_s+\k+)?'
  let l:namedpat = '%(\{(%(\k|\_s|,)*)\})?'
  let l:frompat = '\_s+from\_s+([''"][^''"]+[''"])\_s*;?'
  let l:pat = '\v\C^\s*import\_s+' . l:defaultpat . '\_s*' . l:namespacepat
        \ . '\_s*' . l:namedpat .  l:frompat . '(.*)'
  let l:matches = matchlist(a:statement, l:pat)
  call s:logger.Debug('Pattern %s on %s got %s', l:pat, a:statement, l:matches)
  if empty(l:matches)
    return {}
  endif
  let l:parsed.trailing = l:matches[5]
  if !empty(l:matches[1])
    let l:parsed.default = s:newIdentifier(
          \ s:withoutAlias(l:matches[1]), s:aliasSymbol(l:matches[1]))
  endif
  if !empty(l:matches[2])
    let l:parsed.namespace = s:newIdentifier('*', s:aliasSymbol(l:matches[2]))
  endif
  if !empty(l:matches[3])
    for l:named in split(l:matches[3], ',')
      call add(l:parsed.named,
            \ s:newIdentifier(s:withoutAlias(l:named), s:aliasSymbol(l:named)))
    endfor
  endif
  let l:parsed.from = trim(l:matches[4], "\"'")
  let l:parsed.fromquote = l:matches[4][0]
  return l:parsed
endfunction

function! s:importToString(parsed) abort
  let l:pieces = ['import']
  if !empty(a:parsed.default.symbol)
    let l:comma = empty(a:parsed.namespace) && empty(a:parsed.named) ? '' : ','
    call add(l:pieces, s:identifierToString(a:parsed.default) . l:comma)
  endif
  if !empty(a:parsed.namespace.symbol)
    call add(l:pieces, s:identifierToString(a:parsed.namespace))
  endif
  if !empty(a:parsed.named)
    call add(l:pieces, printf('{%s}',
          \ join(maktaba#function#Map(
                \ a:parsed.named, function('s:identifierToString')),
          \ ', ')))
  endif
  call add(l:pieces, 'from')
  call add(l:pieces,
        \ a:parsed.fromquote . a:parsed.from . a:parsed.fromquote
              \ . ';' . a:parsed.trailing)
  call s:logger.Debug('Formatting %s from %s', l:pieces, a:parsed)
  return join(l:pieces, ' ')
endfunction

function! s:mergeImport(into, add) abort
  if empty(a:add.from) || a:add.from !=# a:into.from
    " not the same import source
    call s:logger.Debug('Module %s != %s', a:add.from, a:into.from)
    return a:into
  endif
  let l:merged = deepcopy(a:into)
  for l:key in ['default', 'namespace']
    if !empty(a:add[l:key].symbol) && a:add[l:key] != a:into[l:key]
      if !empty(a:into[l:key].symbol)
        " can't have two defaults or two namespace aliases
        call s:logger.Debug('%s %s is already %s',
              \ l:key, a:add[l:key], a:into[l:key])
        return a:into
      endif
      call s:logger.Debug('Adding %s %s to merged', l:key, a:add[l:key])
      let l:merged[l:key] = deepcopy(a:add[l:key])
    endif
  endfor
  for l:named in a:add.named
    if index(l:merged.named, l:named) < 0
      call s:logger.Debug('Adding named %s to merged', l:named)
      call add(l:merged.named, l:named)
      call s:logger.Debug('merged.named = %s', l:merged.named)
    else
      call s:logger.Debug('Named %s already in merged %s',
            \ l:named, l:merged.named)
    endif
  endfor
  if len(l:merged.named) > len(a:into.named)
    call sort(l:merged.named, function('s:compareIdentifiers'))
    call s:logger.Debug('sorted merged.named = %s', l:merged.named)
  endif
  return l:merged
endfunction

function! s:newIdentifier(symbol, alias) abort
  return {'symbol': a:symbol, 'alias': a:alias}
endfunction

function! s:identifierToString(identifier) abort
  if empty(a:identifier.alias)
    return a:identifier.symbol
  endif
  return a:identifier.symbol . ' as ' . a:identifier.alias
endfunction

function! s:compareIdentifiers(x, y) abort
  if a:x.symbol ==# a:y.symbol
    if a:x.alias ==# a:y.alias
      return 0
    endif
    return a:x.alias <# a:y.alias ? -1 : 1
  endif
  return a:x.symbol <# a:y.symbol ? -1 : 1
endfunction

function! s:withoutAlias(identifier) abort
  return trim(substitute(a:identifier, '\v\C\_s+as\_s+.*', '', ''))
endfunction

function! s:aliasSymbol(alias) abort
  let l:matches = matchlist(a:alias, '\v\C^.*<as\_s+(\k+)')
  return empty(l:matches) ? '' : l:matches[1]
endfunction
