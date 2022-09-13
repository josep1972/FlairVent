local caps   = require('st.capabilities')
local utils  = require('st.utils')
local base64  = require('st.base64')
local neturl = require('net.url')
local log    = require('log')
local json   = require('dkjson')
local cosock = require "cosock"
local http   = cosock.asyncify "socket.http"
--local https   = cosock.asyncify "ssl.https"
--local https   = require("ssl.https")

local ltn12  = require('ltn12')
local xml2lua = require("xml2lua")
local xml_handler = require "xmlhandler.tree"

local command_handler = {}

------------------
-- Init
function command_handler.init(_, device)
   
   -- Set initial display values
   command_handler.refresh(nil,device)
   
end

------------------
-- Refresh command
function command_handler.refresh(_, device)
   command_handler.getStatus(device)
end

------------------------
-- Get Status
function command_handler.getStatus(device)

   log.debug("Get Status")

   -- Hopefully the token can be used more than once?
   local token = command_handler.getToken(device)
   
   if token ~= "0" then
      command_handler.ventStatus(device,token)
   else 
      log.debug("Bad Token: "..token)
   end
   
end

------------------
-- Push
function command_handler.push(_, device, command)
   local state = device:get_field("state")

   if state == nil then
      state = "open"
      device:set_field("state", state)
   end
   log.debug("Push: "..state)

   if state == "open" then
      device:emit_event(caps.doorControl.door("closing"))
      state = "close"
   else
      device:emit_event(caps.doorControl.door("opening"))
      state = "open"
   end 

   log.debug("Push: "..state)   
   local ventId = device:get_field("ventId")
      
   if ventId ~= nil then
      local token = command_handler.getToken(device)
      
      if token ~= "0" then 
      
         local apiEndpoint = device:get_field("apiEndpoint")      
         local url         = apiEndpoint .. "/flairOpenVent.php?token="..token.."&ventId="..ventId.."&state="..state
         log.debug("URL: "..url)

         local response = {}
         local _, code = http.request({
            url=url,
            sink=ltn12.sink.table(response)
         })
         if code == 200 then
      
            log.debug("200: Push")
            response = table.concat(response).."}"
            log.debug("Response: "..response)
         
            device.thread:call_with_delay(
               30,
               function() 
                  command_handler.ventStatus(device,token)
               end
            )
         end
      else 
         log.debug("Bad Token")
      end
   else 
      log.debug("Bad Vent Id")   
   end

end 

-----------------
-- Get Auth Token
function command_handler.getToken(device)
   log.debug("Token Cmd")
   
   local token = "0"
   local response = {}
   --local scope    = "scope=pucks.view+pucks.edit+structures.view+structures.edit"
   --local clientId = "client_id="..device.preferences.clientId
   --local secret   = "client_secret="..device.preferences.secret
   -- local url      = device.preferences.apiEndpoint.."/oauth/token?"
   -- local data     = clientId.."&"..secret.."&"..scope.."&grant_type=client_credentials"
   -- url = url..data
   local apiEndpoint = device:get_field("apiEndpoint")
   local url = apiEndpoint.."/flairToken.php"
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   --log.debug("BODY: "..table.concat(body))
   --log.debug("CODE: "..code)
   --log.debug("HEADERS: "..table.concat(headers))
   --log.debug("STATUS: "..status)
   
   -- got the access token
   if code == 200 then
      log.debug("200: Token")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)

      local jsonData = json.decode(response)
      token = jsonData["access_token"]
      
      log.debug("TOKEN: "..token)
   end
   
   return token
end

-------------- 
-- Vent Status
function command_handler.ventStatus(device, token)

   local response = {}
   local ventId = device:get_field("ventId")
   local apiEndpoint = device:get_field("apiEndpoint")
   local url = apiEndpoint .. "/flairVentStatus.php?token="..token.."&ventId="..ventId
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   -- log.debug("CODE: "..code)
   
   if code == 200 then
      log.debug("200: Vent Status")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)
      
      local jsonData = json.decode(response)
      
      -- door status
      local open = jsonData["data"]["attributes"]["percent-open"]
      
      if open == 0 then 
         log.debug("Door: Closed")
         device:emit_event(caps.doorControl.door("closed", {state_change = true} ))
         device:set_field("state", "closed")         
      else
         log.debug("Door: Open")
         device:emit_event(caps.doorControl.door("open", {state_change = true} ))
         device:set_field("state", "open")         
      end
      
      -- battery 
      local battery        = jsonData["data"]["attributes"]["voltage"]
      local batteryPercent = math.floor(battery / 3.3 * 100 + 0.5)
      if batteryPercent > 100 then
         batteryPercent = 100
      end
  
      log.debug("Battery (V): "..battery)
      
      device:emit_event(caps.battery.battery(batteryPercent))

   end

end 

return command_handler
