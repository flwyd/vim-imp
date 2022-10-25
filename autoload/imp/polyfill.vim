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

if exists('*flattennew')
  function! imp#polyfill#Flattennew(list, ...) abort
    return call('flattennew', [a:list] + a:000)
  endfunction
else
  ""
  " Polyfill for |flattennew()| for users before Vim 8.2.2449.  Flattens
  " {list} up to [maxdepth] levels.  Without [maxdepth], flattens all levels.
  " Returns a new list; the original is not changed.
  " @public
  function! imp#polyfill#Flattennew(list, ...) abort
    let l:result = []
    for l:i in a:list
      if type(l:i)  == v:t_list
        if a:0 == 0
          call extend(l:result, imp#polyfill#Flattennew(l:i))
        elseif a:1 > 0
          call extend(l:result, imp#polyfill#Flattennew(l:i, a:1 - 1))
        else
          call add(l:result, l:i)
        endif
      else
        call add(l:result, l:i)
      endif
    endfor
    return l:result
  endfunction
endif
