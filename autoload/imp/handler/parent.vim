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

let s:plugin = maktaba#plugin#Get('imp')

function! imp#handler#parent#Location(context) abort
  let l:levels = s:plugin.Flag('parent[levels]')
  call maktaba#ensure#IsTrue(l:levels >= 0,
        \ 'parent[levels] must be non-negative, not %d', l:levels)
  " use relative paths if we can, but absolute paths if not deep enough
  let l:heads = repeat(':h', l:levels + 1)
  let l:mod = l:levels > len(maktaba#path#Split(a:context.path))
        \ ? ':p' .  l:heads : l:heads
  return [fnamemodify(a:context.path, l:mod)]
endfunction
