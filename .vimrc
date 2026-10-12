call plug#begin('~/.vim/plugged')

" --- Наш плагин для буфера обмена ---
Plug 'ojroques/vim-oscyank', {'branch': 'main'}

" --- Навигация и файлы ---
Plug 'nvim-tree/nvim-web-devicons'
Plug 'nvim-tree/nvim-tree.lua'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " Быстрый поиск файлов по системе (размытый поиск)
Plug 'junegunn/fzf.vim'

" --- Внешний вид и интерфейс ---
Plug 'vim-airline/vim-airline'          " Красивая и информативная статус-бар панель внизу
Plug 'vim-airline/vim-airline-themes'   " Темы оформления для этой панели
Plug 'joshdick/onedark.vim'             " Приятная темная цветовая схема (One Dark)

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

" ==========================================
" --- Настройки нового nvim-tree.lua ---
" ==========================================

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



" Настройки копирования OSCYank (оставляем те, что вы нашли)
nmap <leader>c <Plug>OSCYankOperator
nmap <leader>cc <leader>c_
vmap <leader>c <Plug>OSCYankVisual

" ==========================================
" --- Настройка красивого внешнего вида ---
" ==========================================

" 1. Включаем поддержку TrueColor (24-битный цвет в Konsole)
if (has("termguicolors"))
    set termguicolors
endif

" 2. Активируем темную цветовую схему
syntax on
colorscheme onedark
set background=dark

" 3. Настраиваем нижнюю панель (vim-airline)
let g:airline_theme='onedark'           " Тема для панели под цвет редактора
let g:airline#extensions#tabline#enabled = 1 " Включить красивую панель вкладок сверху
let g:airline_powerline_fonts = 1       " Включить сглаженные стрелочки (требуются Powerline шрифты)

" Переключение между открытыми файлами (буферами) по кнопке Tab
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>

