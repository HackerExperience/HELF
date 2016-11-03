defmodule HELF.Mailer do
  alias Bamboo.Email, as: BEmail

  @mailers Application.fetch_env!(:helf, :mailers)
  @default_author Application.fetch_env!(:helf, :default_author)

  def send_email(params \\ []) do
    author =
      Keyword.get(params, :from, @default_author)
      |> format_entity()

    target =
      Keyword.fetch!(params, :to)
      |> format_entity()

    subject = Keyword.fetch!(params, :subject)
    html = Keyword.fetch!(params, :html)
    text = Keyword.fetch!(params, :text, "")

    BEmail.new_email()
    |> BEmail.from(author)
    |> BEmail.to(target)
    |> BEmail.subject(subject)
    |> BEmail.html_body(html)
    |> BEmail.text_body(text)
    |> do_send()
  end

  defp do_send(email) do
    Enum.reduce_while(@mailer, :error, fn (mailer, _) ->
      do_send(mailer, email)
    end)
  end

  defp do_send(mailer, email) do
    try do
      mailer.deliver_now(payload)
      {:halt, {:ok, mailer}}
    rescue
      Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
      Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
      Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
      Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
      Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
    end
  end

  defp format_entity({name, email}),
    do: "#{name} <#{email}>"
  defp format_entity(email),
    do: email
end