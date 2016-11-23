defmodule Bamboo.MailerTest do
  use ExUnit.Case
  use Bamboo.Test

  alias HELF.Mailer

  @sender "example <example@email.com>"
  @receiver "example <example@email.com>"
  @subject "Example Subject"
  @text "Example Text"
  @html "<p>Example HTML</p>"

  describe "send email without piping" do
    test "receiver is required" do
      assert_raise KeyError, fn ->
        assert :error = Mailer.send(from: @sender, subject: "", html: "")
      end
    end

    test "subject is required" do
      assert_raise KeyError, fn ->
        assert :error = Mailer.send(from: @sender, to: @receiver, html: "")
      end
    end

    test "html is required" do
      assert_raise KeyError, fn ->
        assert :error = Mailer.send(from: @sender, to: @receiver, subject: "")
      end
    end

    test "sender is not required since it fallbacks to config" do
      assert {:ok, _} = Mailer.send(to: @receiver, subject: "", html: "")
    end

    test "email is sent" do
      assert {:ok, _} = Mailer.send(from: @sender, to: @receiver, subject: "", html: "")
    end
  end

  describe "piping validations" do
    test "email is not sent without a receiver" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.subject(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)

      assert :error = Mailer.send(email)
      refute_delivered_email email
    end

    test "email is sent without a text body" do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.html(@html)

      assert {:ok, _} = Mailer.send(email)
    end
  end

  describe "send email with piping" do
    setup do
      email =
        Mailer.new()
        |> Mailer.from(@sender)
        |> Mailer.to(@receiver)
        |> Mailer.subject(@subject)
        |> Mailer.text(@text)
        |> Mailer.html(@html)

      {:ok, email: email}
    end

    test "email is sent using default mailer", %{email: email} do
      assert {:ok, _} = Mailer.send(email)
      assert_delivered_email email
    end

    test "email is not sent", %{email: email} do
      assert :error = Mailer.send(email, [HELF.Mailer.RaiseMailer])
      refute_delivered_email email
    end

    test "email is sent using a fallback mailer", %{email: email} do
      mailers = [HELF.Mailer.RaiseMailer, HELF.Mailer.RaiseMailer, HELF.Mailer.TestMailer]
      assert {:ok, {_, HELF.Mailer.TestMailer}} = Mailer.send(email, mailers)
      assert_delivered_email email
    end
  end
end