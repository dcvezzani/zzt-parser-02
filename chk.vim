function! JumpZzt()
  let @z = 'v/:h"wy'
  normal @z
  " call search(@w, 'bW')
  call search(@w)
  "/"wp
endfunction
  
nmap <buffer> qu :call JumpZzt()<CR>

