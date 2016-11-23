use Mix.Config

config :logger,
  level: :info,
  compile_time_purge_level: :info

config :helf,
  router_port: 8080,
  mailers: [HELF.Mailer.TestMailer],
  default_sender: "sender@config.com"

config :helf, HELF.Mailer.TestMailer,
  adapter: Bamboo.TestAdapter

if Mix.env === :dev do
  config :remix,
    escript: true,
    silent: true
end