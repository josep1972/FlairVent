local Driver = require('st.driver')
local caps   = require('st.capabilities')
local log    = require('log')

-- local imports
local discovery  = require('discovery')
local lifecycles = require('lifecycles')
local commands   = require('commands')

--------------------
-- Driver definition
local driver =
  Driver(
    'Flair-Vent-Driver',
    {
      discovery          = discovery.handle_discovery,
      lifecycle_handlers = lifecycles,
      supported_capabilities = {
        caps.doorControl,
        caps.battery,
        caps.refresh
      },
      capability_handlers = {
      
        -- Refresh command handler
        [caps.refresh.ID] = {
           [caps.refresh.commands.refresh.NAME] = commands.refresh
        },
        
        -- Push
        [caps.doorControl.ID] = {
           [caps.doorControl.commands.open.NAME]  = commands.push,
           [caps.doorControl.commands.close.NAME] = commands.push
        }
        
      }
    }
  )

--------------------
-- Initialize Driver
driver:run()
