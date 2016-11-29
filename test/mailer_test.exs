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

  describe "test mailers" do
    setup do
      email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.to(@subject)
        |> Mailer.html(@html)

      {:ok, email: email}
    end

    test "RaiseMailer always fails", %{email: email} do
      for _ <- 1..100 do
        assert {:error, ^email} = Mailer.send(email, [RaiseMailer])
      end
    end

    test "Mailer will fallback to the next mailer on the list", %{email: email} do
      for _ <- 1..100 do
        {:ok, result} =
          Mailer.send(email, [RaiseMailer, RaiseMailer, TestMailer])
        assert TestMailer == result.mailer
      end
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
        |> Mailer.to(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)
      assert {:ok, _} = Mailer.send(email)
    end
  end

  describe "email sending" do
    test "Mailer uses the configured default sender when the from field is not set" do
      email =
        Mailer.new()
        |> Mailer.to(@receiver)
        |> Mailer.to(@subject)
        |> Mailer.html(@html)

      assert email.from == Application.fetch_env!(:helf, :default_sender)
      assert {:ok, _} = Mailer.send(email)
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
        |> Mailer.to(@subject)
        |> Mailer.html(@html)

      assert {:ok, result} = Mailer.send(email)
      assert email == result.email
    end

    test "email sent with send/1 and send_async/1 are identical" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.to(@subject)
        |> Mailer.html(@html)

      email_sync = Mailer.send(email)
      email_async =
        email
        |> Mailer.send_async(notify: true)
        |> Mailer.await()

      assert email_async == email_sync

      email_sync = Mailer.send(email, [RaiseMailer])
      email_async =
        email
        |> Mailer.send_async([notify: true], [RaiseMailer])
        |> Mailer.await()
      assert email_async == email_sync
    end
  end
end