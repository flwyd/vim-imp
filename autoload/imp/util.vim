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

""
" @public
" Variadic function which always returns 0.
function! imp#util#AlwaysFalse(...) abort
  return 0
endfunction

""
" Not marked public until TODO below is resolved.
" Returns {val} if it is a list, values if it's a dict,empty list if it's null
" or none, and a single-element list containing val otherwise.
function! imp#util#ToList(val) abort
  if maktaba#value#IsList(a:val)
    return a:val
  elseif maktaba#value#IsDict(a:val)
    return values(a:val)
  elseif type(a:val) == type(v:null)
    return []
  else
    " TODO consider if empty string -> empty list would be convenient
    return [a:val]
  endif
endfunction

""
" @public
" Compares two values in the natural way, returning 0 if the two are equal
" according to `==#`, -1 if `a <# b` and 1 if `a ># b`.
function! imp#util#Cmp(a, b) abort
  if a:a ==# a:b
    return 0
  endif
  if a:a <# a:b
    return -1
  endif
  return 1
endfunction

""
" @public
" Compares two lists element-wise, using {cmp} as an element comparator which
" returns less than zero, zero, or greater than zero.  If lists {a} or {b} are
" a prefix of the other, the shorter list compares less.  {cmp} may be any
" maktaba callable, including '|imp#util#Cmp|' for natural sorting.
function! imp#util#CompareLists(cmp, a, b) abort
  for l:i in range(min([len(a:a), len(a:b)]))
    let l:c = maktaba#function#Apply(a:cmp, a:a[l:i], a:b[l:i])
    if l:c != 0
      return l:c
    endif
  endfor
  return len(a:a) - len(a:b)
endfunction

""
" @public
" Returns the first item in {list} where {expr} (a maktaba Callable which
" accepts a single argument) returns a truthy value.  Returns |v:null| if no
" item in the list matched.
function! imp#util#Find(list, expr) abort
  call maktaba#ensure#IsList(a:list)
  call maktaba#ensure#IsCallable(a:expr)
  for l:val in a:list
    if maktaba#function#Apply(a:expr, l:val)
      return l:val
    endif
  endfor
  return v:null
endfunction

""
" @public
" Returns a new list of items in {list1} which are also present in {list2}.
" This uses an O(n^2) algorithm because dicts use string keys which would
" conflate equality for some items.
function! imp#util#Intersection(list1, list2) abort
  call maktaba#ensure#IsList(a:list1)
  call maktaba#ensure#IsList(a:list2)
  " TODO Filter isn't supposed to modify input, see
  " https://github.com/google/vim-maktaba/issues/250
  return maktaba#function#Filter(
        \ copy(a:list1), {val -> index(a:list2, val) >= 0})
endfunction

""
" @public
" {a} and {b} must both be either strings or lists.  Returns a string or list
" (matching the input type) with the common elements at the beginning of both
" {a} and {b}.
function! imp#util#SharedPrefix(a, b) abort
  call maktaba#ensure#TypeMatches(
        \ maktaba#ensure#TypeMatchesOneOf(a:a, ['', []]),
        \ maktaba#ensure#TypeMatchesOneOf(a:b, ['', []]))
  let l:end = 0
  for l:i in range(min([len(a:a), len(a:b)]))
    if a:a[l:i] !=# a:b[l:i]
      break
    endif
    let l:end = l:i+1
  endfor
  return slice(a:a, 0, l:end)
endfunction

""
" @public
" {a} and {b} must both be either strings or lists.  Returns a string or list
" (matching the input type) with the common elements at the end of both {a}
" and {b}.
function! imp#util#SharedSuffix(a, b) abort
  call maktaba#ensure#TypeMatches(
        \ maktaba#ensure#TypeMatchesOneOf(a:a, ['', []]),
        \ maktaba#ensure#TypeMatchesOneOf(a:b, ['', []]))
  " string doesn't support negative indexes like l:s[-2] but does support
  " negatives in range like l:s[-2:]
  if maktaba#value#IsString(a:a)
    let l:result = ''
    for l:i in range(-1, -min([len(a:a), len(a:b)]), -1)
      let l:x = a:a[l:i:]
      let l:y = a:b[l:i:]
      if l:x ==# l:y
        let l:result = l:x
      else
        break
      endif
    endfor
    return l:result
  endif
  let l:step = 0
  for l:i in range(-1, -min([len(a:a), len(a:b)]), -1)
    if a:a[l:i] !=# a:b[l:i]
      break
    endif
    let l:step += 1
  endfor
  return slice(a:a, len(a:a) - l:step)
endfunction

""
" @public
" Returns a list of values by concatenating argument lists.  If any argument is
" a string, it is presumed to be a user-set flag value for a list of
" command line arguments, and split on non-escaped spaces.  Otherwise, the
" argument must be a list. A single list is returned, but no extra flattening is
" performed.
function! imp#util#ArgsList(...) abort
  let l:result = []
  for l:val in a:000
    call maktaba#ensure#TypeMatchesOneOf(l:val, [[], ''])
    if maktaba#value#IsList(l:val)
      let l:result += l:val
    else
      if l:val !~# '^\s*$'
        let l:result += split(l:val, '\\\@<! \+')
      endif
    endif
  endfor
  return l:result
endfunction

""
" @public
" Returns a list of \[linenum, linetext\] in the current buffer mathching {pat}.
" If {pat} is a string, it is treated as a pattern for |match()|, otherwise it
" is treated as a maktaba callable predicate, passing each line as a string to
" the function and adding it to the result if the function returns a truthy
" value.  If [IgnoreComments] is a maktaba callable, it is called with the line
" number of each line before {pat} is checked, and the line is skipped before if
" it returns true.  As a convenience, [IgnoreComments] can be 1 (default) to use
" |imp#util#IsCommentOrStringLine| as the predicate and 0 to use
" |imp#util#AlwaysFalse|.  If [StopIf] is non-empty, it will be called with
" the line text for each line, before {pat} is checked.  If [StopIf] returns
" true, this and all further lines will be ignored.  This allows only
" examining the top part of a file for imports.
function! imp#util#FindLines(pat, ...) abort
  let l:ignoreComment = get(a:, 1, 1)
  if maktaba#value#IsNumber(l:ignoreComment)
    let l:Ignore = maktaba#function#Create(
          \ l:ignoreComment ? 'imp#util#IsCommentLine' : 'imp#util#AlwaysFalse')
  else
    let l:Ignore = maktaba#function#Create(l:ignoreComment)
  endif
  let l:StopIf = maktaba#function#Create(get(a:, 2, ''))
  let l:Predicate = maktaba#value#IsString(a:pat)
        \ ? {x -> match(x, a:pat) >= 0}
        \ : maktaba#ensure#IsFuncref(a:pat)
  let l:result = []
  for l:linenum in range(1, line('$'))
    if l:Ignore.Apply(l:linenum)
      continue
    endif
    let l:line = getline(l:linenum)
    if l:StopIf.Apply(l:line)
      return l:result
    endif
    if l:Predicate(l:line)
      let l:result += [[l:linenum, l:line]]
    endif
  endfor
  return l:result
endfunction

""
" @public
" Returns true if it is likely that line {linenum} of the current buffer is
" a comment.  Implementation may change, but currently checks if the the
" first non-blank character in the line has comment syntax.
function! imp#util#IsCommentLine(linenum) abort
  return imp#util#IsSyntaxLine(['comment'], a:linenum)
endfunction

""
" @public
" Returns true if it is likely that line {linenum} of the current buffer is
" a comment or part of a (multiline) string.  Implementation may change, but
" currently checks if the the first non-blank character in the line has
" comment or string syntax.
function! imp#util#IsCommentOrStringLine(linenum) abort
  return imp#util#IsSyntaxLine(['comment', 'string'], a:linenum)
endfunction

""
" @public
" Returns true if the first non-blank character of line number {linenum} in the
" current buffer matches one of the syntax names in list {synnames}.  Checks the
" first column if the line contains only whitespace.  Will generally return
" false if the line has no characters.  {synnames} is the first argument to aid
" |Partial| or |maktaba#function#WithArgs| applications.  Name comparisons are
" case-insensitive.
function! imp#util#IsSyntaxLine(synnames, linenum) abort
  call maktaba#ensure#IsNumber(a:linenum)
  let l:names = maktaba#function#Map(imp#util#ToList(a:synnames), 'tolower')
  if empty(a:synnames)
    return 0
  endif
  let l:col = indent(a:linenum) + 1
  if l:col < 0
    let l:col = 1
  endif
  let l:syntax = synIDattr(synIDtrans(synID(a:linenum, l:col, 1)), 'name')
  return maktaba#value#IsIn(tolower(l:syntax), a:synnames)
endfunction

""
" @public
" Returns the symbol (as determined by |iskeyword|) currently under or next to
" the cursor, like |cword| but also looking back one character.  Returns empty
" string if the cursor is not near a symbol.
function! imp#util#CursorSymbol() abort
  " In insert mode, <cword> is forward-looking, so expand('<cword>') returns
  " nothing with cursor position | in 'foo|' and returns bar in 'foo| bar'
  " which would be surprising for insert-mode mappings.  So match keyword chars
  " leading up to and following cursor position first; if that's whitespace,
  " fall back to <cword>.
  let l:word = matchstr(getline('.'), '\k*\%' . virtcol('.') . 'v\k*')
  if empty(l:word)
    let l:word = expand('<cword>')
    if match(l:word, '\k') < 0
      " cursor is not in or next to a word
      return ''
    endif
  endif
  return l:word
endfunction
