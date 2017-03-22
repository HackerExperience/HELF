use Mix.Config

config :logger,
  level: :info,
  compile_time_purge_level: :info

config :helf,
  router_port: 8080

config :helf, HELF.Mailer,
  mailers: [HELF.MailerTest.TestMailer],
  default_sender: "sender@config.com"

config :helf, HELF.MailerTest.TestMailer,
  adapter: Bamboo.TestAdapter