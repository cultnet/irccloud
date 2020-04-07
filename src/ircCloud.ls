{ MultiSend } = require (if process.env.CULTNET_LIVE is \true then \@cultnet/send-queue/src/sendQueue else \@cultnet/send-queue)
{ Bus } = require (if process.env.CULTNET_LIVE is \true then \@cultnet/bus/src/bus else \@cultnet/bus)
{ obj-to-pairs, each } = require \prelude-ls
IC = require \irccloud

export IrcCloud = { start }

function start email, password, options
  console.log "connecting to irccloud"
  irc = new IC!
  send = new MultiSend!
  if options?.speed-limits
    options.speed-limits |> obj-to-pairs |> each ([key, value]) ->
      send.throttle key, value
  irc.on \loaded attach-handlers
  irc.connect email, password
  irc.on \disconnect process.exit

  function attach-handlers
    console.log "connected to irccloud"
    relay \message (buffer, sender, text) -> { text }
    relay \action (buffer, sender, text) -> { text }
    relay \join (buffer, user) -> {}
    relay \part (buffer, user) -> {}
    Bus.receive \action \message \irccloud ({ target, text }) ->
      conn = irc.connections[target.cid]
      if not conn then return # TODO oohohokk
      buffer = conn.buffers[target.bid]
      text.split \\n |> each (line) -> send.push conn.name, -> irc.message conn, buffer.name, text

  function relay event, props
    irc.on event, (buffer, sender, ...args) ->
      conn = irc.connections[buffer.cid]
      return if options?.whitelist and (not (options.whitelist.includes conn.name))
      Bus.send \event, event, \irccloud, {
        source: { buffer.cid, buffer.bid }
        server: conn.name
        channel: buffer.name
        nick: sender.nick
        user-id: sender.nick
        is-mine: sender.nick is irc.nick
        ...(props buffer, sender, ...args)
      }
