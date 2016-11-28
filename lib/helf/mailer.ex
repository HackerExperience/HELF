defmodule HELF.Mailer do
  @moduledoc """
  Provides methods for sending emails with a list of Bamboo mailers.

  It will try to use the first mailer available for sending the email, and
  fallback to the next available mailer one if the current one fails.

  Before start using the module, add a `mailers` field to your `helf` app
  configuration, it must be a list of Bamboo mailers.
  """

  @type params :: [{:notify, boolean}]
  @type compose_params :: [
    {:from, String.t}
    | {:to, String.t}
    | {:subject, String.t}
    | {:text, String.t}
    | {:html, String.t}
  ]
  @opaque email :: Bamboo.Email.t

  @mailers Application.get_env(:helf, :mailers)
  @default_sender Application.get_env(:helf, :default_sender)

  defmodule SentEmail do
    @moduledoc """
    Holds information about an already sent email.
    """

    @type t :: %__MODULE__{}

    @enforce_keys [:email, :mailer]
    defstruct [:email, :mailer]
  end

  defmodule AsyncEmail do
    @moduledoc """
    Holds information about an email being sent.

    Use with `HELF.Mailer.await` and `HELF.Mailer.yield`.
    """

    @opaque t :: %__MODULE__{}

    @enforce_keys [:notify?, :reference, :process]
    defstruct [:notify?, :reference, :process]
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

  @spec send_async(email) :: AsyncEmail.t
  @doc """
  Sends the `email` from another processs using configured mailers.
  """
  def send_async(email = %Bamboo.Email{}),
    do: send_async(email, [], @mailers)

  @spec send_async(email, params) :: AsyncEmail.t
  @doc """
  Sends the `email` from another processs using configured mailers, also
  accepts a `notify` param that allows waiting with `await` or `yield`.
  """
  def send_async(email = %Bamboo.Email{}, params),
    do: send_async(email, params, @mailers)

  @spec send_async(email, params, mailers :: [module, ...]) :: AsyncEmail.t
  @doc """
  Sends the `email` from another processs using a explicit mailers list.
  """
  def send_async(email = %Bamboo.Email{}, params, mailers)
  when mailers != nil and mailers != []
  do
    me = self()
    ref = make_ref()
    notify? = Keyword.get(params, :notify, false)

    process = spawn fn ->
      status = do_send(email, mailers)

      if notify? do
        case status do
          {:ok, result} ->
            Kernel.send(me, {:email, :success, ref, result})
          :error ->
            Kernel.send(me, {:email, :fail, ref, email})
        end
      end
    end

    %AsyncEmail{notify?: notify?, reference: ref, process: process}
  end

  @spec await(AsyncEmail.t, timeout :: non_neg_integer) ::
    nil
    | {:ok, Email.t}
    | {:error, email}
    | :error
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

  @spec yield(AsyncEmail.t, timeout :: non_neg_integer) ::
    nil
    | {:ok, SentEmail.t}
    | {:error, email}
    | :error
  @doc """
  Awaits until email is sent, yields `:error` on timeout.
  """
  def yield(%AsyncEmail{notify?: true, reference: ref}, timeout \\ 5_000) do
    case wait_message(ref, timeout) do
      :timeout ->
        :error
      return ->
        return
    end
  end

  @spec send(email) :: {:ok, AsyncEmail.t} | :error
  @doc """
  Sends the `email` using mailers from the config.
  """
  def send(email = %Bamboo.Email{}),
    do: send_async(email, notify: true) |> yield()

  @spec send(email, timeout :: non_neg_integer) :: {:ok, SentEmail.t} | :error
  @doc """
  Sends the `email` using mailers from the config, optionally accepts a timeout.
  """
  def send(email = %Bamboo.Email{}, timeout),
    do: send_async(email, notify: true) |> yield(timeout)

  @spec send(email, mailers :: [module, ...], timeout) ::
    {:ok, SentEmail.t}
    | :error
  @doc """
  Sends the `email` using a explicit mailers list from the last param,
  also accepts a timeout.
  """
  def send(email = %Bamboo.Email{}, timeout, mailers),
    do: send_async(email, [notify: true], mailers) |> yield(timeout)

  @spec do_send(email :: Bamboo.Email.t, mailers :: [:module, ...]) ::
    {:ok, SentEmail.t}
    | :error
  @docp """
  Tries to send the email using the first available mailer, will fallback
  to the next mailer on error.
  """
  defp do_send(email, mailers) do
    Enum.reduce_while(mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, %SentEmail{email: email, mailer: mailer}}}
      rescue
        Bamboo.MailgunAdapter.ApiError -> {:cont, :error}
        Bamboo.MandrillAdapter.ApiError -> {:cont, :error}
        Bamboo.SendgridAdapter.ApiError -> {:cont, :error}
        Bamboo.SentEmail.DeliveriesError -> {:cont, :error}
        Bamboo.SentEmail.NoDeliveriesError -> {:cont, :error}
      end
    end)
  end

  @spec wait_message(SentEmail.t, timeout :: non_neg_integer) ::
    nil
    | {:ok, EmailSent.t}
    | :error
  @docp """
  Blocks until email is sent or timeout is reached.
  """
  defp wait_message(reference, timeout) do
    receive do
      {:email, :success, ^reference, email_sent} ->
        {:ok, email_sent}
      {:email, :fail, ^reference, email} ->
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