{ obj-to-pairs, each } = require \prelude-ls
IC = require \irccloud

export IrcCloud = { start }

function start email, password, options
  irc = new IC!
  queues = new SendQueue!
  if options?.speed-limits
    options.speed-limits |> obj-to-pairs |> each ([key, value]) ->
      queues.throttle key, value
  irc.on \loaded attach-handlers
  irc.connect email, password
  irc.on \disconnect process.exit

  function attach-handlers
    relay \message (buffer, sender, text) -> { text }
    relay \action (buffer, sender, text) -> { text }
    relay \join (buffer, user) -> {}
    relay \part (buffer, user) -> {}
    Bus.receive \command \message \irccloud ({ target, text }) ->
      conn = irc.connections |> Object.values |> find (c) -> c.name is target.connection
      if not conn return
      text.split \\n |> each (line) -> queues.push conn.name, -> irc.message conn, target.buff

  function relay event props
    irc.on event, (buffer, sender, ...args) ->
      conn = irc.connections[buffer.cid]
      return if options?.whitelist and (not (options.whitelist.includes conn.name))
      Bus.send \event, event, \irccloud
        server: conn.name
        channel: buffer.name
        nick: sender.nick
        user-id: sender.nick
        is-mine: sender.nick is irc.nick
        ...(props buffer, sender, ...args)
