defmodule HELF.Mailer do
  @moduledoc """

  """

  alias Bamboo.Email
  import Kernel, except: [send: 2]

  @mailers Application.get_env(:helf, :mailers, [])
  @default_sender Application.get_env(:helf, :default_sender, nil)

  @enforce_keys [:email, :mailer]
  defstruct [:email, :mailer]

  @opaque t :: %__MODULE__{}
  @type params :: [
    {:from, String.t}
    | {:to, String.t}
    | {:subject, String.t}
    | {:text, String.t}
    | {:html, String.t}
  ]

  @doc """
  Sets the email sender.
  """
  @spec from(Email.t, sender :: String.t) :: Email.t
  defdelegate from(email, sender),
    to: Email

  @doc """
  Sets the email recipient.
  """
  @spec to(Email.t, receiver :: String.t) :: Email.t
  defdelegate to(email, receiver),
    to: Email

  @doc """
  Sets the email subject.
  """
  @spec subject(Email.t, subject :: String.t) :: Email.t
  defdelegate subject(email, subject),
    to: Email

  @doc """
  Sets the text body of the `email`.
  """
  @spec text(Email.t, text :: String.t) :: Email.t
  defdelegate text(email, text),
    to: Email,
    as: :text_body

  @doc """
  Sets the html body of the `email`.
  """
  @spec html(Email.t, html :: String.t) :: Email.t
  defdelegate html(email, html),
    to: Email,
    as: :html_body

  @doc """
  Creates a new email, optionally accepts a `Keyword` that is used for composing the email.
  """
  @spec new() :: Email.t
  @spec new(params) :: Email.t
  def new() do
    Email.new_email()
    |> from(@default_sender)
  end
  def new(parameters=[_|_]) do
    new()
    |> compose(parameters)
  end

  @doc """
  Sends the `email` using `mailers`.
  """
  @spec send(Email.t) :: {:ok, t} | :error
  @spec send(Email.t, mailers :: [atom]) :: {:ok, t} | :error
  def send(email = %Email{}) do
    send(email, @mailers)
  end
  def send(email = %Email{}, mailers) do
    Enum.reduce_while(mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, %__MODULE__{email: email, mailer: mailer}}}
      rescue
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
        Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
        Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
        Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
        Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
      end
    end)
  end

  @docp """
  Composes the email using a `Keyword` list.
  """
  @spec compose(Email.t, params) :: Email.t
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