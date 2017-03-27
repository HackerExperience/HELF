defmodule HELF.Mailer do
  @moduledoc """
  Provides a way for sending emails with a list of Bamboo mailers.

  It will try to send the email using the first available mailer, and then
  fallback to the next whenever the current one fails.

  Before using the module, you should configure the list of mailers, this
  is what it should looks like:

      config :helf, HELF.Mailer,
        mailers: [HELM.Mailer.MailGun, HELM.Mailer.Maldrill],
        default_sender: "sender@config.com"

  The default sender is completely optional.
  """

  @type params :: [
    {:from, String.t}
    | {:to, String.t}
    | {:subject, String.t}
    | {:text, String.t}
    | {:html, String.t}
  ]
  @opaque email :: Bamboo.Email.t

  @config Application.get_env(:helf, __MODULE__, [])

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

    @type t :: %__MODULE__{}

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
  Creates a new empty email, see new/1 for composing emails using the params.
  """
  def new do
    Bamboo.Email.new_email()
    |> from(Keyword.get(@config, :default_sender))
  end

  @spec new(params) :: email
  @doc """
  Creates and composes a new email using the params.
  """
  def new(parameters = [_|_]) do
    new()
    |> compose(parameters)
  end

  @spec send_async(
    email,
    params :: [{:notify, boolean} | {:mailers, [module, ...]}]) :: AsyncEmail.t
  @doc """
  Sends the `email` from another processs, optionally accepts `notify` and
  `mailers` keywords.

  To use `await` and `yield` methods, set the `notify` keyword to true.
  """
  def send_async(email, params \\ []) do
    me = self()
    ref = make_ref()
    default_mailers = Keyword.get(@config, :mailers)
    notify? = Keyword.get(params, :notify, false)
    mailers = Keyword.get(params, :mailers, default_mailers)

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
    {:ok, SentEmail.t}
    | {:error, email}
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
    {:ok, SentEmail.t}
    | {:error, email}
    | nil
  @doc """
  Awaits until email is sent, yields `nil` on timeout.
  """
  def yield(%AsyncEmail{notify?: true, reference: ref}, timeout \\ 5_000) do
    case wait_message(ref, timeout) do
      :timeout ->
        nil
      return ->
        return
    end
  end

  @spec send(email, params :: [{:mailers, [module, ...]}]) ::
    {:ok, SentEmail.t}
    | {:error, email}
    | {:error, :internal_error}
  @doc """
  Sends the `email`, optionally accepts a `mailers` keyword.
  """
  def send(email = %Bamboo.Email{}, params \\ []) do
    request = send_async(email, [{:notify, true} | params])
    pid = request.process
    ref = Process.monitor(pid)
    receive do
      {:DOWN, ^ref, :process, ^pid, _} ->
        case wait_message(request.reference, 0) do
          :timeout -> {:error, :internal_error}
          msg -> msg
        end
      after
        5_000 ->
          {:error, :internal_error}
    end
  end

  @spec do_send(email :: Bamboo.Email.t, mailers :: [module, ...]) ::
    {:ok, SentEmail.t}
    | :error
  # Tries to send the email using the first available mailer, then fallbacks
  # to the next mailer on error.
  defp do_send(email, mailers) do
    Enum.reduce_while(mailers, :error, fn mailer, _ ->
      try do
        mailer.deliver_now(email)
        {:halt, {:ok, %SentEmail{email: email, mailer: mailer}}}
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

  @spec wait_message(reference, timeout :: non_neg_integer) ::
    {:ok, SentEmail.t}
    | {:error, email}
    | :timeout
  # Blocks until email is sent or timeout is reached.
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
  # Composes the email using keywords.
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
