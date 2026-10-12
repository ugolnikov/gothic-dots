" gothic.vim — vim-airline theme (gothic palette).
" airline sources this file and reads the palette below at the top level.
" Color arrays are [ guifg, guibg, ctermfg, ctermbg ].

let g:airline#themes#gothic#palette = {}

" a: mode block (bone on blood), b: branch/file, c: rest
let s:A = [ '#0a0a0b', '#a31621', 233, 88 ]
let s:B = [ '#d6d1c9', '#17171a', 250, 234 ]
let s:C = [ '#8b857c', '#101013', 245, 233 ]

let g:airline#themes#gothic#palette.normal = airline#themes#generate_color_map(s:A, s:B, s:C)
let g:airline#themes#gothic#palette.terminal = airline#themes#generate_color_map(s:A, s:B, s:C)

let g:airline#themes#gothic#palette.insert = airline#themes#generate_color_map(
      \ [ '#0a0a0b', '#8f7a4a', 233, 137 ], s:B, s:C)
let g:airline#themes#gothic#palette.replace = airline#themes#generate_color_map(
      \ [ '#0a0a0b', '#8b5a63', 233, 95 ], s:B, s:C)
let g:airline#themes#gothic#palette.visual = airline#themes#generate_color_map(
      \ [ '#0a0a0b', '#6c4f8f', 233, 98 ], s:B, s:C)

let g:airline#themes#gothic#palette.inactive = airline#themes#generate_color_map(
      \ [ '#4a4a52', '#101013', 240, 233 ],
      \ [ '#4a4a52', '#101013', 240, 233 ],
      \ [ '#4a4a52', '#101013', 240, 233 ])

" accents must be arrays: [ guifg, guibg, ctermfg, ctermbg ]
let g:airline#themes#gothic#palette.accents = { 'red': [ '#c81e3a', '', 160, '' ] }

let g:airline#themes#gothic#palette.normal_modified =
      \ { 'airline_c': [ '#c81e3a', '#101013', 160, 233, '' ] }
let g:airline#themes#gothic#palette.insert_modified = g:airline#themes#gothic#palette.normal_modified
let g:airline#themes#gothic#palette.visual_modified = g:airline#themes#gothic#palette.normal_modified
let g:airline#themes#gothic#palette.replace_modified = g:airline#themes#gothic#palette.normal_modified
