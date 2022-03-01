require('telescope').setup {
  defaults = {
    file_sorter = require('telescope.sorters').get_fzy_sorter,
    prompt_prefix = ' >',
    color_devicons = true,

    file_previewer = require('telescope.previewers').vim_buffer_cat.new,
    grep_previewer = require('telescope.previewers').vim_buffer_vimgrep.new,
    qflist_previewer = require('telescope.previewers').vim_buffer_qflist.new,

    file_ignore_patterns = {
      "^node_modules/",
      ".git/"
    },

    mappings = {
      i = {
        ["<C-x>"] = false,
      }
    },
  },

  pickers = {
    find_files = {
      theme = "dropdown",
      find_command = {
        "rg", "--ignore", "--hidden", "--files",
      }
    }
  },

  extentions = {
    fzy_native = {
      overriden_generic_sorter = false,
      overriden_file_sorter = true,
    }
  }
}

require('telescope').load_extension('fzy_native')

local M = {}
M.search_dotfiles = function()
  require('telescope.builtin').find_files({
    prompt_title = '< VimRC >',
    cwd = "~/"
  })
end
return M
