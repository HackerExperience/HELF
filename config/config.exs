use Mix.Config

config :helf,
  router_port: 8080,
  mailers: [HELF.MailgunMailer]

config :helf, HELF.MailgunMailer,
  adapter: Bamboo.MailgunAdapter,
  api_key: System.get_env("HELF_MAILER_MAILGUN_API"),
  domain: System.get_env("HELF_MAILER_MAILGUN_DOMAIN")

config :remix,
  escript: true,
  silent: true
