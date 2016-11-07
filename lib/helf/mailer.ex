defmodule HELF.Mailer do
  alias Bamboo.Email, as: BEmail

  @mailers Application.fetch_env!(:helf, :mailers)
  @default_sender Application.fetch_env!(:helf, :default_sender)

  def write(params \\ []) do
    sender = Keyword.get(params, :from, @default_sender)
    receiver = Keyword.fetch!(params, :to)
    subject = Keyword.fetch!(params, :subject)
    html = Keyword.fetch!(params, :html)
    text = Keyword.get(params, :text, "")

    email = BEmail.new_email()
    |> BEmail.from(sender)
    |> BEmail.to(receiver)
    |> BEmail.subject(subject)
    |> BEmail.html_body(html)
    |> BEmail.text_body(text)
  end

  def send(email) do
    Enum.reduce_while(@mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, mailer}}
      rescue
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
        Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
        Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
        Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
        Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
      end
    end)
  end
end