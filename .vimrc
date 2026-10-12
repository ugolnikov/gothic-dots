call plug#begin('~/.vim/plugged')

" --- Наш плагин для буфера обмена ---
Plug 'ojroques/vim-oscyank', {'branch': 'main'}

" --- Навигация и файлы ---
" nvim-tree — только для Neovim
if has('nvim')
  Plug 'nvim-tree/nvim-web-devicons'
  Plug 'nvim-tree/nvim-tree.lua'
endif
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " Быстрый поиск файлов по системе (размытый поиск)
Plug 'junegunn/fzf.vim'

" --- Внешний вид и интерфейс ---
Plug 'vim-airline/vim-airline'          " Красивая и информативная статус-бар панель внизу
Plug 'vim-airline/vim-airline-themes'   " Темы оформления для этой панели
" (цветовая схема — своя, готическая, см. конец файла)

" --- Редактирование текста и автодополнение ---
Plug 'tpope/vim-commentary'             " Быстрое комментирование строк (нажмите gcc)
Plug 'tpope/vim-surround'               " Удобная работа с кавычками и скобками (замена, удаление)
Plug 'jiangmiao/auto-pairs'             " Автоматическое закрытие скобок и кавычек при вводе
Plug 'Yggdroot/indentLine'              " Визуальные вертикальные линии для отступов в коде

call plug#end()

" ============================================================================
" --- Рекомендуемые базовые настройки Vim для этих плагинов (добавьте ниже) ---
" ============================================================================
syntax on                               " Включить подсветку синтаксиса
set number                              " Включить номера строк
set mouse=a                             " Разрешить прокрутку колесиком мыши в Vim
set tabstop=4                           " Размер таба — 4 пробела
set shiftwidth=4                        " Размер отступа при форматировании
set expandtab                           " Превращать табы в пробелы

" --- Русская раскладка (ЙЦУКЕН) ---
" Команды и маппинги в Normal/командной строке работают как латинские,
" а в Insert-режиме текст вставляется кириллицей. Так dd/gg/:wq и т.п.
" работают и на русской раскладке без переключения языка.
set langmap=фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz,ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ

" ==========================================
" --- Настройки нового nvim-tree.lua (только Neovim) ---
" ==========================================
if has('nvim')

" Переназначаем клавишу Ctrl+N на открытие нового дерева файлов
nnoremap <C-n> :NvimTreeToggle<CR>

" Блок инициализации настроек на языке Lua
lua << EOF
-- Отключаем стандартный netrw (встроенный старый проводник Vim)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Включаем 24-битную палитру для корректного отображения иконок
vim.opt.termguicolors = true

-- Базовая конфигурация nvim-tree
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  view = {
    width = 30,                       -- Ширина боковой панели
    side = "left",                    -- Расположение слева
  },
  renderer = {
    group_empty = true,               -- Схлопывать пустые папки в одну строку
    icons = {
      show = {
        file = true,
        folder = true,
        folder_arrow = true,
        git = true,                   -- Показывать статус Git прямо на файлах
      },
    },
  },
  filters = {
    dotfiles = false,                 -- Показывать скрытые файлы (начинающиеся с точки)
  },
})
EOF

endif



" Настройки копирования OSCYank (оставляем те, что вы нашли)
nmap <leader>c <Plug>OSCYankOperator
nmap <leader>cc <leader>c_
vmap <leader>c <Plug>OSCYankVisual

" ==========================================
" --- Готическая тема (свои цвета) ---
" ==========================================
set background=dark
syntax on
if (has("termguicolors"))
    set termguicolors
endif

hi Normal        guifg=#d6d1c9 guibg=#0a0a0b ctermfg=250 ctermbg=233
hi Comment       guifg=#4a4a52 ctermfg=240
hi Constant      guifg=#8f7a4a ctermfg=137
hi String        guifg=#9d8ec7 ctermfg=139
hi Identifier    guifg=#d6d1c9 ctermfg=250
hi Function      guifg=#b8975a ctermfg=143
hi Statement     guifg=#c81e3a ctermfg=160
hi Keyword       guifg=#c81e3a ctermfg=160
hi PreProc       guifg=#8b6fb0 ctermfg=104
hi Type          guifg=#b07585 ctermfg=132
hi Special       guifg=#b07585 ctermfg=132
hi Underlined    guifg=#6c4f8f gui=underline cterm=underline
hi Error         guifg=#0a0a0b guibg=#a31621 ctermfg=233 ctermbg=88
hi Todo          guifg=#0a0a0b guibg=#8f7a4a ctermfg=233 ctermbg=137
hi LineNr        guifg=#4a4a52 ctermfg=240
hi CursorLine    guibg=#17171a ctermbg=234
hi CursorLineNr  guifg=#a31621 ctermfg=88
hi Visual        guibg=#17171a ctermbg=234
hi Pmenu         guifg=#d6d1c9 guibg=#17171a ctermfg=250 ctermbg=234
hi PmenuSel      guifg=#0a0a0b guibg=#a31621 ctermfg=233 ctermbg=88
hi StatusLine    guifg=#d6d1c9 guibg=#17171a gui=bold ctermfg=250 ctermbg=234
hi StatusLineNC  guifg=#8b857c guibg=#101013 ctermfg=245 ctermbg=233
hi VertSplit     guifg=#232327 ctermfg=236
hi MatchParen    guifg=#c81e3a gui=bold ctermfg=160
hi Search        guifg=#0a0a0b guibg=#8f7a4a ctermfg=233 ctermbg=137
hi IncSearch     guifg=#0a0a0b guibg=#c81e3a ctermfg=233 ctermbg=160
hi NonText       guifg=#232327 ctermfg=236
hi SpecialKey    guifg=#232327 ctermfg=236
hi EndOfBuffer   guifg=#0a0a0b ctermfg=233
hi SignColumn    guibg=#0a0a0b ctermbg=233
hi Folded        guifg=#8b857c guibg=#101013 ctermfg=245 ctermbg=233
hi ALEErrorSign  guifg=#a31621 ctermfg=88
hi ALEWarningSign guifg=#8f7a4a ctermfg=137

" Нижняя панель (vim-airline) — своя готическая тема
let g:airline_theme='gothic'
" vim (не nvim) должен видеть ~/.config/nvim на runtimepath,
" чтобы найти autoload/airline/themes/gothic.vim
if !has('nvim')
    set runtimepath^=~/.config/nvim
endif
let g:airline#extensions#tabline#enabled = 1 " Включить красивую панель вкладок сверху
let g:airline_powerline_fonts = 1       " Включить сглаженные стрелочки (требуются Powerline шрифты)

" Переключение между открытыми файлами (буферами) по кнопке Tab
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

