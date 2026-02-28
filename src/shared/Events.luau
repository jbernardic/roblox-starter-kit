local Net = require(shared.Net)
local Events = {}

Events.ClientLoaded = Net.CreateEvent("ClientLoadedEvent")

return Events