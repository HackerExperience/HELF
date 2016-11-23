defmodule HELF.Mailer do
  alias Bamboo.Email

  @mailers Application.fetch_env!(:helf, :mailers)
  @default_sender Application.fetch_env!(:helf, :default_sender)

  defmodule RaiseMailer do
    @errors [
      Bamboo.MailgunAdapter.ApiError,
      Bamboo.MandrillAdapter.ApiError,
      Bamboo.SendgridAdapter.ApiError,
      Bamboo.SentEmail.DeliveriesError,
      Bamboo.SentEmail.NoDeliveriesError
    ]

    def deliver_now(_email),
      do: raise(Enum.random(@errors), %{params: "{}", response: "{}"})
  end

  defmodule TestMailer do
    use Bamboo.Mailer, otp_app: :helf
  end

  defdelegate new(),
    to: Email,
    as: :new_email

  defdelegate from(email, sender),
    to: Email

  defdelegate to(email, receiver),
    to: Email

  defdelegate subject(email, subject),
    to: Email

  defdelegate text(email, sender),
    to: Email,
    as: :text_body

  defdelegate html(email, sender),
    to: Email,
    as: :html_body

  def send(params = [_|_]),
    do: HELF.Mailer.send(params, @mailers)
  def send(email = %Email{}),
    do: HELF.Mailer.send(email, @mailers)

  def send(params = [_|_], mailers) do
    sender = Keyword.get(params, :from, @default_sender)
    receiver = Keyword.fetch!(params, :to)
    subject = Keyword.fetch!(params, :subject)
    html = Keyword.fetch!(params, :html)
    text = Keyword.get(params, :text)

    new()
    |> from(sender)
    |> to(receiver)
    |> subject(subject)
    |> html(html)
    |> text(text)
    |> HELF.Mailer.send(mailers)
  end
  def send(email = %Email{}, mailers) do
    Enum.reduce_while(mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, {email, mailer}}}
      rescue
        Bamboo.NilRecipientsError -> {:halt, :error}
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
        Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
        Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
        Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
        Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
      end
    end)
  end
end