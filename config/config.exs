use Mix.Config

config :helf,
  router_port: 8080,
  mailers: [],
  default_sender: ""

if Mix.env === :dev do
  config :remix,
    escript: true,
    silent: true
end