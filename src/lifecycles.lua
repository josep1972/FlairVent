local command_handler = require('commands')
local log             = require('log')
local json            = require('dkjson')

local apiEndpoint = "http://192.168.1.99:100"
local lifecycle_handler = {}
function lifecycle_handler.init(driver, device)

  local deviceInfo = json.decode(device.device_api.get_device_info(device.id))
  local flairId = deviceInfo["device_network_id"]
  
  device:set_field("ventId",flairId)
  device:set_field("apiEndpoint",apiEndpoint)

   log.info("[" .. device.id .. "] Initializing Flair Vent. Vent Id = "..flairId)
   
   command_handler.init(nil, device)

   -- Refresh every 2 minutes schedule
   device.thread:call_on_schedule(
      600,
      function ()
         return command_handler.refresh(nil, device)
      end
   )
end

function lifecycle_handler.added(driver, device) 
  log.info("[" .. device.id .. "] Added Flair Vent")
end

function lifecycle_handler.removed(_, device)
  log.info("[" .. device.id .. "] Removing Flair Vent")
end

function lifecycle_handler.device_info_changed(driver, device, event, args)
  
  log.info("[" .. device.id .. "] Updating Settings to Flair Vent")
  command_handler.refresh(nil, device)
end

return lifecycle_handler
