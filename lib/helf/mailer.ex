defmodule HELF.Mailer do
  alias Bamboo.Email, as: BEmail

  def email(params \\ []) do
    mailers = Application.fetch_env!(:helf, :mailers)
    default_sender = Application.fetch_env!(:helf, :default_sender)

    payload = BEmail.new_email(
      from: Keyword.get(params, :from, default_sender),
      to: Keyword.fetch!(params, :to),
      subject: Keyword.fetch!(params, :subject),
      html_body: Keyword.fetch!(params, :html),
      text_body: Keyword.fetch!(params, :text)
    )

    Enum.reduce_while(mailers, :error, fn (mailer, _) ->
      try do
        mailer.deliver_now(payload)
        {:halt, {:ok, mailer}}
      rescue
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
      end
    end)
  end
end