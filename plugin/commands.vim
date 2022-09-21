let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" @usage [] [symbols...]
" Suggest a possible import statements for each [symbol], present a picker
" interface for any symbol with multiple suggestions, and add chosen import
" statements to the current buffer.  Example, which might show a picker to
" choose `import java.util.List;` or `import java.awt.List;`: >
"   :ImpSuggest Collection List Set
" <
" Partially-qualified imports may work as well, e.g. `:ImpSuggest Math.max` to
" get `import static java.lang.Math.max;`
"
" @default symbol=the word at the cursor
command -nargs=* -bar ImpSuggest call <SID>Import({}, [<f-args>])

""
" @usage [] [symbols...]
" Suggest a single import statement for each [symbol] and add it to the current
" buffer, bypassing the Pick step.  Example: >
"   :ImpFirst Collection List Set
" <
" @default symbol=the word at the cursor
command -nargs=* -bar ImpFirst call <SID>Import({'max': 1}, [<f-args>])

""
" Prints a list of registered handlers.  If one or more [matches...] is given,
" only handlers registered for those filetypes or implementing those methods
" will be shown.  NOTE: output format is subject to change.  Example: >
"   :ImpHandlers java Suggest
" <
command -nargs=* -bar ImpHandlers call imp#handler#PrintList(<f-args>)

function! s:Import(addcontext, symbols) abort
  if empty(a:symbols)
    let l:word = imp#util#CursorSymbol()
    if empty(l:word)
      let l:word = input('Symbol to import: ', '')
      if empty(l:word)
        echo 'No symbol selected'
        return
      endif
    endif
    let l:symbols = [l:word]
  else
    let l:symbols = a:symbols
  endif
  let l:loop = {'i': 0, 'symbols': l:symbols}
  function l:loop.Next(context) abort dict
    if self.i < len(self.symbols)
      let l:symbol = self.symbols[self.i]
      let self.i += 1
      call imp#ImportSymbol(self.Done, a:context, l:symbol)
    else
      call imp#ReportImported(a:context)
    endif
  endfunction
  let l:loop.Done = maktaba#function#Create(l:loop.Next, [], l:loop)
  call l:loop.Next(imp#NewContext(a:addcontext))
endfunction
