defmodule HELF.Mailer do
  @moduledoc """
  Provides methods for sending emails with a list of Bamboo mailers.

  It will try to use the first mailer available for sending the email, and fallback
  to the next available mailer one if the current one fails.

  Before start using the module, add a `mailers` field to your `helf` app configuration,
  it must be a list of Bamboo mailers.
  """

  import Kernel, except: [send: 2]

  @mailers Application.get_env(:helf, :mailers)
  @default_sender Application.get_env(:helf, :default_sender)

  @opaque email :: Bamboo.Email.t
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
    @type t :: %__MODULE__{}
  end

  defmodule AsyncEmail do
    @enforce_keys [:notify?, :reference, :process]
    defstruct [:notify?, :reference, :process]
    @opaque t :: %__MODULE__{}
  end

  @spec from(email, sender :: String.t) :: email
  @doc """
  Sets the email sender.
  """
  defdelegate from(email, sender),
    to: Bamboo.Email

  @spec to(email, receiver :: String.t) :: email
  @doc """
  Sets the email recipient.
  """
  defdelegate to(email, receiver),
    to: Bamboo.Email

  @spec subject(email, subject :: String.t) :: email
  @doc """
  Sets the email subject.
  """
  defdelegate subject(email, subject),
    to: Bamboo.Email

  @spec text(email, text :: String.t) :: email
  @doc """
  Sets the text body of the `email`.
  """
  defdelegate text(email, text),
    to: Bamboo.Email,
    as: :text_body

  @spec html(email, html :: String.t) :: email
  @doc """
  Sets the html body of the `email`.
  """
  defdelegate html(email, html),
    to: Bamboo.Email,
    as: :html_body

  @spec new() :: email
  @doc """
  Creates a new empty email, see new/1 for composing emails with keywords.
  """
  def new do
    new(from: @default_sender)
  end

  @spec new(params) :: email
  @doc """
  Creates and composes a new email with keywords.
  """
  def new(parameters = [_|_]) do
    Bamboo.Email.new_email()
    |> compose(parameters)
  end

  @spec send(email) :: {:ok, EmailSent.t} | :error
  @doc """
  Sends the `email` using configured mailers.
  """
  def send(email = %Bamboo.Email{}) do
    send(email, @mailers || [])
  end

  @spec send(email, mailers :: [atom]) :: {:ok, EmailSent.t} | :error
  @doc """
  Sends the `email` using a mailer list from the last param.
  """
  def send(email = %Bamboo.Email{}, mailers) do
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

  @spec send_async(email) :: Task.t
  @doc """
  Sends the `email` from another processs using configured mailers.
  """
  def send_async(email = %Bamboo.Email{}),
    do: send_async(email, [], @mailers)

  @spec send_async(email, params :: [{:notify, boolean}]) :: Task.t
  @doc """
  Sends the `email` from another processs using configured mailers, also accepts a `notify` param
  that allows waiting email sending with `await` or `yield`.
  """
  def send_async(email = %Bamboo.Email{}, params),
    do: send_async(email, params, @mailers)

  @spec send_async(email, params :: [{:notify, boolean}], mailers :: [atom]) :: Task.t
  @doc """
  Sends the `email` from another processs without using the mailer list from config, uses mailers
  from the params instead.
  """
  def send_async(email = %Bamboo.Email{}, params, mailers) do
    me = self()
    ref = make_ref()
    notify? = Keyword.get(params, :notify, false)

    process = spawn fn ->
      status = send(email, mailers)

      if notify? do
        case status do
          {:ok, result} ->
            Kernel.send(me, {:email, :sucess, ref, result})
          :error ->
            Kernel.send(me, {:email, :failed, ref, email})
        end
      end
    end

    %AsyncEmail{notify?: true, reference: ref, process: process}
  end

  @spec await(AsyncEmail.t, timeout :: non_neg_integer) :: nil | {:ok, EmailSent.t} | :error
  @doc """
  Awaits until email is sent, will raise `RuntimeError` on timeout.
  """
  def await(%AsyncEmail{notify?: true, reference: ref}, timeout \\ 5_000) do
    case wait_message(ref, timeout) do
      :timeout ->
        raise RuntimeError
      return ->
        return
    end
  end

  @spec yield(AsyncEmail.t, timeout :: non_neg_integer) :: nil | {:ok, EmailSent.t} | :error
  @doc """
  Awaits until email is sent, yields nil on timeout.
  """
  def yield(%AsyncEmail{notify?: true, reference: ref}, timeout \\ 5_000) do
    case wait_message(ref, timeout) do
      :timeout ->
        nil
      return ->
        return
    end
  end

  @spec wait_message(AsyncEmail.t, timeout :: non_neg_integer) :: nil | {:ok, EmailSent.t} | :error
  @docp """
  Blocks until email is sent or timeout is reached.
  """
  defp wait_message(reference, timeout) do
    receive do
      {:email, :sucess, ^reference, email_sent} ->
        {:ok, email_sent}
      {:email, :failed, ^reference, email} ->
        {:error, email}
    after
      timeout ->
        :timeout
    end
  end

  @spec compose(email, params) :: email
  @docp """
  Composes the email using keywords.
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