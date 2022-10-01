local netmsg = "discordmessage"

local col_dgray = col_dgray or Color( 100, 100, 100 )
local col_white = col_white or Color( 255, 255, 255 )

net.Receive( netmsg, function( len )

    local id = net.ReadString()
    local col = net.ReadString()
    local name = net.ReadString()
    local msg = net.ReadString()

    col = Color( tonumber( col:sub( 2, 3 ), 16 ), tonumber( col:sub( 4, 5 ), 16 ), tonumber( col:sub( 6, 7 ), 16 ) )

    hook.Run( "DiscordSay", id, col, name, msg )

end )

hook.Add( "DiscordSay", netmsg, function( id, col, name, msg )

    chat.AddText( col_dgray, "[Discord] ", col, name, col_white, ": ", msg )

end )
