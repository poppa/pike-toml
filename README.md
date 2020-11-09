# TOML parser for [Pike](https://pike.lysator.liu.se)

A [TOML](https://github.com/toml-lang/toml) parser trying to comply to the
v0.5 spec.

## Examle

```toml
# config.toml

name = "Global Server Config"
support = ["email@support.com", "055-5555"]
last-updated = 2020-11-10T12:13:14+01:00

[server.dev]
  host = "dev.host.com"
  port = 1337
  tls = false
  os.platform = "CentOS"
  os.version = "6.5"

[server.prod]
  host = "host.com"
  port = 80
  tls = true
  # This is the same as in `server.dev`
  os = { platform = "CentOS", version = "7.6" }

[[regex]]
dot = '\.'

[[regex]]
dot = '\.\.'
```

Pass this file to `Parser.TOML.parse_file()` like so:

```pike
mapping res = Parser.TOML.parse_file("config.toml");
```

and expect `res` to contain the following content:

```pike
([
  "last-updated": Second(Tue 10 Nov 2020 12:13:14 UTC+1),
  "name": "Global Server Config",
  "regex": ({
    ([ "dot": "\\." ]),
    ([ "dot": "\\.\\." ])
  }),
  "server": ([
    "dev": ([
      "host": "dev.host.com",
      "os": ([
        "platform": "CentOS",
        "version": "6.5"
      ]),
      "port": 1337,
      "tls": Val.false
    ]),
    "prod": ([
      "host": "host.com",
      "os": ([
        "platform": "CentOS",
        "version": "7.6"
      ]),
      "port": 80,
      "tls": Val.true
    ])
  ]),
  "support": ({
    "email@support.com",
    "055-5555"
  })
])
```
