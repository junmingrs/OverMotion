vim.api.nvim_create_user_command('OverMotion', function()
  require('overmotion.core').start()
end, {})
