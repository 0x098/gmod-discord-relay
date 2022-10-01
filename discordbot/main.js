var net = require( 'net' );
var socket = new net.Socket();
const Discord = require( 'discord.js' );
const client = new Discord.Client( { intents: [ 'GUILDS', 'GUILD_MESSAGES' ] } );

client.once( 'ready', () => {
    console.log( 'Bot online.' );
} );

client.on( 'message', ( msg ) => {
    if ( msg.channelId == 'CHANNEL ID TO RELAY DISCORD MSG FROM' & msg.author.bot == false ) {

        socket.connect( 27100 );
        socket.write( msg.author.id + '\n' + msg.member.displayHexColor + '\n' + msg.author.username + '\n' + msg.content + '\n' );

        console.log( msg.author.username + ': ' + msg.content ); // prints messages into the discordbot console

        socket.on( 'error', function ( ex ) {
            if ( ex.code == 'ECONNREFUSED' )
                console.log( 'Could not connect to relay!' );
            else
                console.log( ex.message ) ;
        });
        socket.end();
    }
});

client.login( 'YOUR BOT SECRET KEY HERE' );
