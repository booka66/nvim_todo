if exists('g:loaded_todo') | finish | endif
let s:save_cpo = &cpo
set cpo&vim

command! Todo lua require('todo').ShowTodo()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_todo = 1
