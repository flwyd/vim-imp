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

let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif
let s:logger = maktaba#log#Logger('imp')

""
" @dict Context
" A Context dict contains contextual parameters for the life of a command
" which would be burdensome to pass to handlers which might not use it.
" |imp-handlers| take a context dict as their first parameter and may use it
" to pass side-channel values between steps.  Standard Context fields and their
" default values are >
"   {
"     'filetype': &filetype,  " determines available handlers
"     'path': expand('%:p'),  " path to the file being edited
"     'max': 0,               " maximum number of suggestions, 0 for unlimited
"     'imported': [],         " list of Imports inserted during this command
"     'already_imported': [], " list of Imports which were already present
"   }

""
" Creates a @dict(Context) object that can be passed to handlers.  The optional
" [values] argument (a dict) will override defaults.
" @public
function! imp#NewContext(...) abort
  let l:values = maktaba#ensure#IsDict(get(a:, 1, {}))
  let l:result = {
        \ 'filetype': &filetype,
        \ 'path': expand('%:p'),
        \ 'max': 0,
        \ 'imported': [],
        \ 'already_imported': [],
        \ }
  " TODO Call all contextualizers and add to result
  call extend(l:result, l:values)
  return l:result
endfunction

""
" @dict Import
" An Import dict represents a `symbol` and a `statetement` which could be used
" to import that symbol in some programming language.  It also has a `count`
" property which defaults to 1 and can be used for prioritizing imports which
" occur more frequently in existing code.  Additional properties could be set on
" an Import object to convey information to other handlers, but such properties
" are not guaranteed to be set.

""
" @public
" Creates an @dict(Import) object with {symbol} and {statement} properties, plus
" any properties from an optional [extra] dict.
function! imp#NewImport(symbol, statement, ...) abort
  " symbol, statement, and methods can't be overridden by extra
  let l:result = extend({
        \ 'symbol': a:symbol,
        \ 'statement': a:statement,
        \ 'Equals': function('s:importEquals')},
        \ get(a:000, 0, {}), 'keep')
  " Other defaults can be overridden by extra
  return extend(l:result, {'count': 1}, 'keep')
endfunction

""
" @public
" @dict Import.Equals
" Returns 1 if {other} is an @dict(Import) and has the same symbol and statement
" values, 0 otherwise.
function! s:importEquals(other) dict abort
  return maktaba#value#IsDict(a:other)
        \ && has_key(a:other, 'symbol') && has_key(a:other, 'statement')
        \ && self.symbol ==# a:other.symbol
        \ && self.statement ==# a:other.statement
endfunction

""
" Runs a single string {symbol} through the import process of suggest, pick, and
" insert, using the command @dict(Context) {context}.  See @section(handlers)
" for details on these stages.  This process does not call Report handlers,
" which may collect a bundle of imports from a single command; see
" @function(ReportImported) for that.  When the symbol has been imported, calls
" {DoneFunc}, which can be any |maktaba| callable (a string or funcref).  If
" {DoneFunc} is an empty string, no callback will be made.
" @public
function! imp#ImportSymbol(DoneFunc, context, symbol) abort
  return s:importStateMachine(a:DoneFunc, a:context, a:symbol).Suggest()
endfunction

""
" Calls all registered Report handlers (|imp-handlers-report|) for the
" accumulated `imported` and `already_imported` @dict(Import) objects.
" @public
function! imp#ReportImported(context) abort
  let l:args = [a:context,
        \ get(a:context, 'imported', []),
        \ get(a:context, 'already_imported', [])]
  for l:handler in imp#handler#Preferred(a:context, 'Report')
    call maktaba#function#Call(l:handler.Report, l:args)
  endfor
endfunction


" *** State machine for importing a statement ***
" State functions return 1 if the whole machine is done, 0 if waiting on async
" continuation.

function! s:importStateMachine(DoneFunc, context, symbol) abort
  let l:Done = empty(a:DoneFunc) ? 'imp#util#AlwaysFalse' : a:DoneFunc
  let l:machine = {
        \ 'context': maktaba#ensure#IsDict(a:context),
        \ 'symbol': maktaba#ensure#IsString(a:symbol),
        \ 'Done': maktaba#ensure#IsCallable(l:Done),
        \ 'Suggest': function('s:stateSuggest'),
        \ 'suggest': {'suggestions': []},
        \ 'Pick': function('s:statePick'),
        \ 'pick': {'choices': []},
        \ 'Insert': function('s:stateInsert'),
        \ 'insert': {'done': 0},
        \ }
  return l:machine
endfunction

function! s:stateSuggest() abort dict
  call s:logger.Debug('Suggest state for %s', self.symbol)
  let l:stash = self.suggest
  if !has_key(l:stash, 'handlers')
    let l:stash.handlers = imp#handler#Preferred(self.context, 'Suggest')
    let l:stash.handler_i = 0
  endif
  while l:stash.handler_i < len(l:stash.handlers)
    let l:handler = l:stash.handlers[l:stash.handler_i]
    let l:stash.handler_i += 1
    if !imp#handler#IsAvailable(self.context, l:handler, 'Suggest')
      call s:logger.Debug('Suggest handler %s not available', l:handler.name)
      continue
    endif
    if get(l:handler, 'async', 0)
      call s:logger.Debug('Suggest calling async %s', l:handler.name)
      let l:Continue = maktaba#function#Create(
            \ function('s:continueSuggest'), [], self)
      call maktaba#function#Apply(
            \ l:handler.Suggest, l:Continue, self.context, self.symbol)
      return 0
    else
      call s:logger.Debug('Suggest calling %s', l:handler.name)
      let l:stash.suggestions = maktaba#function#Apply(
            \ l:handler.Suggest, self.context, self.symbol)
      call s:logger.Debug('Suggest got %s', l:stash.suggestions)
      if !empty(l:stash.suggestions)
        return self.Pick()
      endif
    endif
  endwhile
  call s:logger.Debug('Suggest got no suggestions')
  " no hanlders produced suggestions, end the state machine
  call maktaba#function#Apply(self.Done, self.context)
  return 1
endfunction

function! s:continueSuggest(suggestions) abort dict
  call s:logger.Debug('Suggest continues for %s with %s',
        \ self.symbol, a:suggestions)
  let self.suggest.suggestions = maktaba#ensure#IsList(a:suggestions)
  if !empty(a:suggestions)
    return self.Pick()
  endif
  return self.Suggest()
endfunction

function! s:statePick() abort dict
  call s:logger.Debug('Pick state for %s with %s',
        \ self.symbol, self.suggest.suggestions)
  let l:stash = self.pick
  if len(self.suggest.suggestions) == 1
    let l:stash.choices = copy(self.suggest.suggestions)
    call s:logger.Debug('Pick skipping handlers for single suggestion')
    return self.Insert()
  endif
  if !has_key(l:stash, 'handlers')
    let l:stash.handlers = imp#handler#Preferred(self.context, 'Pick')
    let l:stash.handler_i = 0
  endif
  while l:stash.handler_i < len(l:stash.handlers)
    let l:handler = l:stash.handlers[l:stash.handler_i]
    let l:stash.handler_i += 1
    if !imp#handler#IsAvailable(self.context, l:handler, 'Pick')
      call s:logger.Debug('Pick handler %s not available', l:handler.name)
      continue
    endif
    if get(l:handler, 'async', 0)
      call s:logger.Debug('Pick calling async %s', l:handler.name)
      let l:Continue = maktaba#function#Create(
            \ function('s:continuePick'), [], self)
      call maktaba#function#Apply(l:handler.Pick,
            \ l:Continue, self.context, self.suggest.suggestions)
      return 0
    else
      call s:logger.Debug('Pick calling %s', l:handler.name)
      let l:stash.choices = maktaba#function#Apply(
            \ l:handler.Pick, self.context, self.suggest.suggestions)
      call s:logger.Debug('Pick got %s', l:stash.choices)
      if !empty(l:stash.choices)
        return self.Insert()
      endif
    endif
  endwhile
  " no hanlders produced suggestions, end the state machine
  call s:logger.Debug('Pick got no choices')
  call maktaba#function#Apply(self.Done, self.context)
  return 1
endfunction

function! s:continuePick(choices) abort dict
  call s:logger.Debug('Pick continues for %s with %s', self.symbol, a:choices)
  let self.pick.choices = maktaba#ensure#IsList(a:choices)
  if !empty(a:choices)
    let self.pick.done = 1
    return self.Insert()
  endif
  return self.Pick()
endfunction

function! s:stateInsert() abort dict
  call s:logger.Debug('Insert state for %s with %s',
        \ self.symbol, self.pick.choices)
  let l:stash = self.insert
  if !has_key(l:stash, 'handlers')
    let l:stash.handlers = imp#handler#Preferred(self.context, 'Insert')
    let l:stash.handler_i = 0
  endif
  while !l:stash.done && l:stash.handler_i < len(l:stash.handlers)
    let l:handler = l:stash.handlers[l:stash.handler_i]
    let l:stash.handler_i += 1
    if !imp#handler#IsAvailable(self.context, l:handler, 'Insert')
      call s:logger.Debug('Insert handler %s not available', l:handler.name)
      continue
    endif
    if get(l:handler, 'async', 0)
      call s:logger.Debug('Insert calling async %s', l:handler.name)
      let l:Continue = maktaba#function#Create(
            \ function('s:continueInsert'), [], self)
      call maktaba#function#Apply(l:handler.Insert,
            \ l:Continue, self.context, self.pick.choices)
      return 0
    else
      call s:logger.Debug('Insert calling %s', l:handler.name)
      let l:stash.done = maktaba#ensure#IsBool(maktaba#function#Apply(
            \ l:handler.Insert, self.context, self.pick.choices))
      call s:logger.Debug('Insert got done=%s', l:stash.done)
    endif
  endwhile
  " Insert is the final step of the state machine
  call s:logger.Debug('Insert for %s added %d statements',
        \ self.symbol, len(self.context.imported))
  call maktaba#function#Apply(self.Done, self.context)
  return 1
endfunction

function! s:continueInsert(success) abort dict
  call s:logger.Debug('Insert continues for %s with done=%s',
        \ self.symbol, a:success)
  let self.insert.done = maktaba#ensure#IsBool(a:success)
  if self.insert.done
    call s:logger.Debug('Insert for %s added %d statements',
          \ self.symbol, len(self.context.imported))
    call self.Done(self.context)
    return 1
  endif
  return self.Insert()
endfunction
