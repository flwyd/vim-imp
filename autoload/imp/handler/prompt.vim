""
" Import suggester which prompts the user for a statement with just the import
" symbol as a suggestion. This is typically used as a fallback if other
" suggesters don't find a match.
function! imp#handler#prompt#Suggest(context, symbol) abort
  let l:statement = input(printf('Import for %s: ', a:symbol), a:symbol)
  return empty(l:statement) ? [] : [imp#NewImport(a:symbol, l:statement)]
endfunction
