if SERVER then
    AddCSLuaFile( "discordrelay/client/discordrelay.lua" )
    include( "discordrelay/server/discordrelay.lua" )
else
    include( "discordrelay/client/discordrelay.lua" )
end
