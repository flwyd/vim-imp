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
" |imp#util#IsCommentLine| as the predicate and 0 to use |imp#util#AlwaysFalse|.
" If [StopIf] is non-empty, it will be called with the line text for each line,
" before {pat} is checked.  If [StopIf] returns true, this and all further lines
" will be ignored.  This allows only examining the top part of a file for
" imports.
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
" Returns true if the first non-blank character of line number {linenum} in the
" current buffer matches one of the syntax names in list {synnames}.  Checks the
" first column if the line contains only whitespace.  Will generally return
" false if the line has no characters.  {synnames} is the first argument to aid
" |Partial| or |maktaba#function#WithArgs| applications.
function! imp#util#IsSyntaxLine(synnames, linenum) abort
  call maktaba#ensure#IsList(a:synnames)
  call maktaba#ensure#IsNumber(a:linenum)
  if empty(a:synnames)
    return 0
  endif
  let l:col = indent(a:linenum) + 1
  if l:col < 0
    let l:col = 1
  endif
  let l:syntax = synIDattr(synIDtrans(synID(a:linenum, l:col, 1)), 'name')
  return maktaba#value#IsIn(l:syntax, a:synnames)
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
