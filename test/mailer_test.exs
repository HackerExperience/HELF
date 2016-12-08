defmodule HELF.MailerTest do
  use ExUnit.Case
  use Bamboo.Test

  alias HELF.Mailer

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

  @receiver "sender <sender@email.com>"
  @sender "receiver <receiver@email.com>"
  @subject "Email Title"
  @html "<p>email html</p>"
  @text "email text"

  describe "test mailer" do
    setup do
      email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      {:ok, email: email}
    end

    test "RaiseMailer always fails", %{email: email} do
      assert {:error, ^email} = Mailer.send(email, mailers: [RaiseMailer])
    end

    test "fallback to the next mailer on the list", %{email: email} do
      {:ok, result} =
        Mailer.send(email, mailers: [RaiseMailer, RaiseMailer, TestMailer])
      assert TestMailer == result.mailer
    end
  end

  describe "writing and sending emails" do
    test "emails created with and without composition are identical" do
      with_pipe =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)

      params = [
        to: @receiver,
        subject: @subject,
        text: @text(),
        html: @html()
      ]

      without_pipe = Mailer.new(params)

      assert without_pipe == with_pipe
    end

    test "write and send email without explicit composition" do
      params = [
        from: @sender,
        to: @receiver,
        subject: @subject,
        text: @text(),
        html: @html()
      ]
      email = Mailer.new(params)
      assert {:ok, _} = Mailer.send(email)
    end

    test "write and send email with composition" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)
      assert {:ok, _} = Mailer.send(email)
    end

    test "use configured default sender when the from field is not set" do
      email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      mailer_config = Application.fetch_env!(:helf, HELF.Mailer)
      default_sender = Keyword.fetch!(mailer_config, :default_sender)

      assert default_sender == email.from
    end

    test "email requires a receiver" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.html(@html)

      assert {:error, _} = Mailer.send(email)
    end

    test "email doesn't require a text body" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      assert {:ok, result} = Mailer.send(email)
      assert email == result.email
    end

    test "both emails sent with send/1 and send_async/1 are identical" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      email_sync = Mailer.send(email)
      email_async =
        email
        |> Mailer.send_async(notify: true)
        |> Mailer.await()

      assert email_async == email_sync

      email_sync = Mailer.send(email, mailers: [RaiseMailer])
      email_async =
        email
        |> Mailer.send_async(notify: true, mailers: [RaiseMailer])
        |> Mailer.await()
      assert email_async == email_sync
    end
  end
end