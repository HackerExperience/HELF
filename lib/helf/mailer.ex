defmodule HELF.Mailer do
  @moduledoc """
  Provides methods for sending emails using a list of fallback mailers.
  Before start using the module, add a `mailers` field to your `helf` app configuration, it must be a list of
  Bamboo mailers.
  """

  alias Bamboo.Email
  import Kernel, except: [send: 2]

  @opaque email :: email
  @type params :: [
    {:from, String.t}
    | {:to, String.t}
    | {:subject, String.t}
    | {:text, String.t}
    | {:html, String.t}
  ]

  defmodule EmailSent do
    @enforce_keys [:email, :mailer]
    defstruct [:email, :mailer]
    @opaque t :: %__MODULE__{}
  end

  @spec from(email, sender :: String.t) :: email
  @doc """
  Sets the email sender.
  """
  defdelegate from(email, sender),
    to: Email

  @spec to(email, receiver :: String.t) :: email
  @doc """
  Sets the email recipient.
  """
  defdelegate to(email, receiver),
    to: Email

  @spec subject(email, subject :: String.t) :: email
  @doc """
  Sets the email subject.
  """
  defdelegate subject(email, subject),
    to: Email

  @spec text(email, text :: String.t) :: email
  @doc """
  Sets the text body of the `email`.
  """
  defdelegate text(email, text),
    to: Email,
    as: :text_body

  @spec html(email, html :: String.t) :: email
  @doc """
  Sets the html body of the `email`.
  """
  defdelegate html(email, html),
    to: Email,
    as: :html_body

  @spec new() :: email
  @doc """
  Creates a new empty email.
  """
  def new do
    Email.new_email()
    |> from(Application.get_env(:helf, :default_sender))
  end

  @spec new(params) :: email
  @doc """
  Creates a new email filled with data from `params`.
  """
  def new(parameters = [_|_]) do
    new()
    |> compose(parameters)
  end

  @spec send(email) :: {:ok, EmailSent.t} | :error
  @doc """
  Sends the `email` using configured mailers.
  """
  def send(email = %Email{}) do
    mailers = Application.fetch_env!(:helf, :mailers)
    send(email, mailers)
  end

  @spec send(email, mailers :: [atom]) :: {:ok, EmailSent.t} | :error
  @doc """
  Sends the `email` without using the mailer list from config, uses mailers from the params instead.
  """
  def send(email = %Email{}, mailers) do
    Enum.reduce_while(mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, %EmailSent{email: email, mailer: mailer}}}
      rescue
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
        Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
        Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
        Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
        Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
      end
    end)
  end

  @spec send_later(email) :: Task.t
  @doc """
  Sends the `email` from another processs using configured mailers.
  """
  def send_later(email) do
    mailers = Application.fetch_env!(:helf, :mailers)
    send_later(email, mailers)
  end

  @spec send_later(email, mailers :: [atom]) :: Task.t
  @doc """
  Sends the `email` from another processs without using the mailer list from
  config, uses mailers from the params instead.
  """
  def send_later(email, mailers) do
    origin = self()
    Task.start fn ->
      case send(email, mailers) do
        {:ok, email} ->
          # forward email delivery messages for testing
          receive do
            {:delivered_email, email} ->
              Kernel.send(origin, {:delivered_email, email})
          end
          {:ok, email}
        :error ->
          :error
      end
    end
  end

  @spec compose(email, params) :: email
  @docp """
  Composes the email using a `Keyword` list.
  """
  defp compose(email, [{:from, val}| t]) do
    email
    |> from(val)
    |> compose(t)
  end
  defp compose(email, [{:to, val}| t]) do
    email
    |> to(val)
    |> compose(t)
  end
  defp compose(email, [{:subject, val}| t]) do
    email
    |> subject(val)
    |> compose(t)
  end
  defp compose(email, [{:text, val}| t]) do
    email
    |> text(val)
    |> compose(t)
  end
  defp compose(email, [{:html, val}| t]) do
    email
    |> html(val)
    |> compose(t)
  end
  defp compose(email, []) do
    email
  end
end