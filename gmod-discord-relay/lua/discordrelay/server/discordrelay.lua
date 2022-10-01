local t = "DiscordRelay"
local netmsg = "discordmessage"

local col_join = Color( 70, 255, 70 )
local col_leave = Color( 255, 70, 70 )
local col_connect = Color( 255, 255, 70 )
local col_red = col_red or Color( 255, 0, 0 )

local BotInfo = {} -- not writing a special .cfg file or anything for this (you can do it yourself tho)
BotInfo.DiscordBotName = "[Cool server name]"  -- your username to show as who posted the message
BotInfo.DiscordBotImageURL = "https://cdn.discordapp.com/attachments/478616407551246336/939484473756618762/74815CB2CBAA5A5CAACC61506A65315E6D0EA335.png"  -- avatar url of the message
BotInfo.DiscordWebhookURL = "https://discord.com/api/webhooks/..."  -- channel webhook url

BotInfo.SteamAPIKey = "..."  -- https://steamcommunity.com/dev/apikey

BotInfo.IngamePlayerFallbackAvatarURL = "https://cdn.discordapp.com/attachments/478616407551246336/939484473756618762/74815CB2CBAA5A5CAACC61506A65315E6D0EA335.png" -- if could not get player img fallback to this
BotInfo.IngameBOTImageURL = "" -- img url of ingame bots (can be empty)


if not DiscordRelay then
    if not socket then
        require( "luasocket" ) -- https://github.com/Metastruct/luadev
    end
    DiscordRelay = assert( socket.tcp() )
    assert( DiscordRelay:bind( "127.0.0.1", 27100 ) )
    DiscordRelay:settimeout( 0 )
    DiscordRelay:setoption( "reuseaddr", true )
    assert( DiscordRelay:listen( 0 ) )
end

if not CHTTP then
    require( "chttp" ) -- https://github.com/timschumi/gmod-chttp
end

util.AddNetworkString( netmsg )

hook.Add( "Think", t, function()
    local cl = DiscordRelay:accept()
    if not cl then return end

    if cl:getpeername() ~= "127.0.0.1" then
        MsgC( col_red, "Refused", cl:getpeername() )
        cl:shutdown()
        return
    end

    local dat = {}

    cl:settimeout( 0 )

    net.Start( netmsg )
    for i = 1, 4 do
        local msg = cl:receive( "*l" )
        net.WriteString( msg )
    end
    net.Broadcast()


    cl:shutdown()
end )


local ColToDecimal = function( col )
    return ( col.r or 0 ) * 65536 + ( col.g or 0 ) * 256 + ( col.b or 0 )
end


local Avatars = {}
local AvatarsApi = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/" -- api url (universal)

local col_red, col_white = col_red or Color( 255, 0, 0 ), col_white or Color( 255, 255, 255 )

local PlayerMessageDiscord = {
    content = "",
    username = "",
    avatar_url = "",
}

local DiscordMessageEmbed = {
    username = BotInfo.DiscordBotName,
    avatar_url = BotInfo.DiscordBotImageURL,
    embeds = {
        {
            color = 0, 
            author = {
                name = "",
                icon_url = "",
                url = ""
            }
        }
    }
}

local DiscordMessage = {
    method = "post",
    type = "application/json; charset=utf-8",
    headers = {
        [ "User-Agent" ] = "Discord Relay?",
    },
    url = BotInfo.DiscordWebhookURL,
    body = util.TableToJSON( DiscordMessageEmbed ),
    failed = function( error )
        MsgC( col_red, "Discord API HTTP Error:", col_white, error, "\n" )
    end,
    success = function( code, response )
        if code ~= 204 then
            MsgC( col_red, "Discord API HTTP Error:", col_white, code, response, "\n" )
        end
    end
}

local function ParseJson( json, ... )
    local tbl = util.JSONToTable( json )
    if tbl == nil then return end

    local args = { ... }

    for _, key in pairs( args ) do
        if tbl[ key ] then
            tbl = tbl[ key ]
        end
    end

    return tbl
end

local GetAvatarHTTPTable = {
    method = "get",
    url = AvatarsApi,
    parameters = {
        key = BotInfo.SteamAPIKey,
        steamids = sid
    },
    failed = function( error )
        MsgC( col_red, "Steam Avatar API HTTP Error:", col_white, error, "\n" )
        attempts = attempts - 1
        if attempts > 0 then
            GetAvatar( ply, callback, attempts )
        else
            Avatars[ sid ] = BotInfo.IngamePlayerFallbackAvatarURL
            callback( Avatars[ sid ] )
        end
    end,
    success = function( code, response )
        local avatar = ParseJson( response, "response", "players", 1, "avatarfull" )
        if avatar then
            Avatars[ sid ] = avatar
            callback( avatar )
        else
            return MsgC( col_red, "Steam Avatar API Error:", col_white, "Cant parse avatar\n" )
        end
    end
}

local function GetAvatar( ply, callback, attempts )
    attempts = attempts or 3
    local sid
    if type( ply ) == "string" and ply:find( "STEAM", 0, true ) then
        sid = util.SteamIDTo64( ply )
    elseif type( ply ) == "Player" then
        if ply:IsBot() then
            return callback( BotInfo.IngameBOTImageURL )
        end
        sid = ply:SteamID64()
    end
    
    if Avatars[ sid ] then
        return callback( Avatars[ sid ] )
    end

    GetAvatarHTTPTable.parameters.steamids = sid

    GetAvatarHTTPTable.failed = function( error )
        MsgC( col_red, "Steam Avatar API HTTP Error:", col_white, error, "\n" )

        attempts = attempts - 1

        if attempts > 0 then
            GetAvatar( ply, callback, attempts )
        else
            Avatars[ sid ] = BotInfo.IngamePlayerFallbackAvatarURL
            callback( Avatars[ sid ] )
        end
    end

    GetAvatarHTTPTable.success = function( code, response )
        local avatar = ParseJson( response, "response", "players", 1, "avatarfull" )

        if avatar then
            Avatars[ sid ] = avatar
            callback( avatar )
        else
            return MsgC( col_red, "Steam Avatar API Error:", col_white, "Cant parse avatar\n" )
        end
    end

    CHTTP( GetAvatarHTTPTable )
end


hook.Add( "PlayerAuthed", t, function( ply )
    GetAvatar( ply, function() end ) -- pre-cache
end )


hook.Add( "FinishedLoading", t, function( ply )
    if ply.IsBot and ply:IsBot() then return end

    GetAvatar( ply, function( avatar )

        DiscordMessageEmbed.embeds[ 1 ].color = ColToDecimal( col_join )
        DiscordMessageEmbed.embeds[ 1 ].author.name = ( "%s spawned" ):format( ply:Nick() )
        DiscordMessageEmbed.embeds[ 1 ].author.icon_url = avatar
        DiscordMessageEmbed.embeds[ 1 ].author.url = ( "https://steamcommunity.com/profiles/%s" ):format( ply:SteamID64() )

        DiscordMessage.body = util.TableToJSON( DiscordMessageEmbed )

        CHTTP( DiscordMessage )
    end )
end )


hook.Add( "player_connect", t, function( data )
    if data.bot == 1 then return end

    local sid64 = util.SteamIDTo64( data.networkid )

    GetAvatar( data.networkid, function( avatar )
        
        DiscordMessageEmbed.embeds[ 1 ].color = ColToDecimal( col_connect )
        DiscordMessageEmbed.embeds[ 1 ].author.name = ( "%s joining" ):format( data.name )
        DiscordMessageEmbed.embeds[ 1 ].author.icon_url = avatar
        DiscordMessageEmbed.embeds[ 1 ].author.url = ( "https://steamcommunity.com/profiles/%s" ):format( sid64 )
        
        DiscordMessage.body = util.TableToJSON( DiscordMessageEmbed )

        CHTTP( DiscordMessage )
    end )
end )


hook.Add( "player_disconnect", t, function( data )
    if data.bot == 1 then return end

    local sid64 = util.SteamIDTo64( data.networkid )

    GetAvatar( data.networkid, function( avatar )

        DiscordMessageEmbed.embeds[ 1 ].color = ColToDecimal( col_leave )
        DiscordMessageEmbed.embeds[ 1 ].author.name = ( "%s left" ):format( data.name )
        DiscordMessageEmbed.embeds[ 1 ].author.icon_url = avatar
        DiscordMessageEmbed.embeds[ 1 ].author.url = ( "https://steamcommunity.com/profiles/%s" ):format( sid64 )

        DiscordMessage.body = util.TableToJSON( DiscordMessageEmbed )

        CHTTP( DiscordMessage )
    end )
end )


hook.Add( "PlayerSay", t, function( ply, text, isteam )
    if not isteam then
        GetAvatar( ply, function( avatar )

            PlayerMessageDiscord.content = text
            PlayerMessageDiscord.username = ply:Nick()
            PlayerMessageDiscord.avatar_url = avatar

            DiscordMessage.body = util.TableToJSON( PlayerMessageDiscord )

            CHTTP( DiscordMessage )
        end )
    end
end )
