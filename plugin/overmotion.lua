vim.api.nvim_create_user_command('OverMotion', function()
  require('overmotion.core').start()
end, {})

vim.api.nvim_create_user_command('OverClient', function()
  require('overmotion.client').start()
end, {})
