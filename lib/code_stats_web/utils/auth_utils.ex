defmodule CodeStatsWeb.AuthUtils do
  @moduledoc """
  Authentication related utilities.
  """

  import Ecto.Query, only: [from: 2]
  alias Ecto.Changeset

  alias CodeStats.Repo
  alias CodeStats.User
  alias CodeStats.User.Machine

  alias Plug.Conn
  alias Plug.Crypto.MessageVerifier

  @auth_key :codestats_user
  @machine_auth_key :codestats_api_machine
  @private_info_key :_codestats_session_user

  @doc """
  Get auth key used for storing user data in session.
  """
  @spec auth_key() :: atom
  def auth_key(), do: @auth_key

  @doc """
  Is the current user authenticated?
  """
  @spec is_authed?(Conn.t()) :: boolean
  def is_authed?(%Conn{} = conn) do
    match?(number when is_integer(number), Conn.get_session(conn, @auth_key))
  end

  @doc """
  Get ID of current user from the session.

  Returns nil if user is not authenticated.
  """
  @spec get_current_user_id(Conn.t()) :: number | nil
  def get_current_user_id(conn) do
    Conn.get_session(conn, @auth_key)
  end

  @doc """
  Get current user model of the authenticated user.

  Returns nil if the user is not authenticated.
  """
  @spec get_current_user(Conn.t()) :: %User{} | nil
  def get_current_user(conn) do
    conn.private[@private_info_key]
  end

  @doc """
  Get private key used for sessions.
  """
  @spec private_info_key() :: atom
  def private_info_key do
    @private_info_key
  end

  @doc """
  Authenticate the given user in the given connection.

  Authentication status is saved in the session. Returns conn on success, :error on failure.
  """
  @spec auth_user(Conn.t(), User.t(), String.t()) :: Conn.t() | :error
  def auth_user(%Conn{} = conn, %User{} = user, password) do
    if check_user_password(user, password) do
      force_auth_user_id(conn, user.id)
    else
      :error
    end
  end

  @doc """
  Put authentication status into session for given user ID.
  """
  def force_auth_user_id(%Conn{} = conn, id) do
    Conn.put_session(conn, @auth_key, id)
  end

  @doc """
  Unauthenticate (log out) the user from the connection.

  The whole session is destroyed.
  """
  @spec unauth_user(Conn.t()) :: Conn.t()
  def unauth_user(%Conn{} = conn) do
    Conn.configure_session(conn, drop: true)
  end

  @doc """
  Fake a user authentication.

  Uses some CPU cycles to make it look like we authenticated a user and checked their
  password. This makes it harder to enumerate users in the system.
  """
  @spec dummy_auth_user() :: nil
  def dummy_auth_user() do
    Bcrypt.no_user_verify()
    nil
  end

  @doc """
  Create a new user and save them to the database.

  Returns an Ecto changeset if validation errors happened.
  """
  @spec create_user(User.t()) :: User.t() | Changeset.t()
  def create_user(changeset) do
    changeset
    |> Repo.insert()
    |> case do
      {:ok, user} -> user
      {:error, changeset} -> changeset
    end
  end

  @doc """
  Update a user's data in the database.

  Returns an Ecto changeset if validation errors happened.
  """
  @spec update_user(Changeset.t()) :: User.t() | Changeset.t()
  def update_user(changeset) do
    changeset
    |> Repo.update()
    |> case do
      {:ok, user} -> user
      {:error, changeset} -> changeset
    end
  end

  @doc """
  Delete user's account if they input the correct thing into the input field. Give the route
  helper and action to use as the last argument, user will be redirected there if they mistype
  the input. Otherwise they will be redirected to the front page after deletion.
  """
  @spec delete_user_action(Conn.t(), map, {function, atom}) :: Conn.t()
  def delete_user_action(conn, params, {route_helper, redirect_action}) do
    user = get_current_user(conn)

    if Map.get(params, "delete_confirmation") == "DELETE" do
      # Delete user in background task to prevent the request from timing out, as deleting all of
      # user's XP will take a long time.
      Task.start(__MODULE__, :delete_user, [user])

      # We cannot delete the whole session here, or the flash message will not be shown. So just
      # delete the auth data.
      conn
      |> Conn.delete_session(auth_key())
      |> Phoenix.Controller.put_flash(
        :info,
        "Your user account will be deleted in a few moments."
      )
      |> Phoenix.Controller.redirect(to: CodeStatsWeb.Router.Helpers.page_path(conn, :index))
    else
      conn
      |> Phoenix.Controller.put_flash(
        :error,
        "Please confirm deletion by typing \"DELETE\" into the input field."
      )
      |> Phoenix.Controller.redirect(to: route_helper.(conn, redirect_action))
    end
  end

  @doc """
  Delete the given user.

  Returns true if succeeded, false if failed.
  """
  @spec delete_user(User.t()) :: boolean
  def delete_user(user) do
    case Repo.delete(user) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Is the current user authenticated to the API with a machine token?
  """
  @spec is_machine_authed?(Conn.t()) :: boolean
  def is_machine_authed?(%Conn{} = conn) do
    match?({%User{}, %Machine{}}, conn.private[@machine_auth_key])
  end

  @doc """
  Authenticate a user in the given connection using the given machine token.

  Authentication status is saved in the connection with the key @machine_auth_key. The key will
  contain a tuple of the authenticated user and the machine they are using.

  If the given token is not valid, nothing is done to the connection.
  """
  @spec auth_machine(Conn.t(), String.t()) :: Conn.t()
  def auth_machine(%Conn{} = conn, machine_token) do
    with {username, machine_id} <- split_token(machine_token),
         %User{} = user <- User.get_by_username(username),
         %Machine{} = machine <- get_machine(machine_id, user),
         {:ok, _} <-
           MessageVerifier.verify(machine_token, conn.secret_key_base <> machine.api_salt) do
      Conn.put_private(conn, @machine_auth_key, {user, machine})
    else
      _ -> conn
    end
  end

  @doc """
  Get the user and machine associated with the given connection.

  Returns nil if user is not API authenticated.
  """
  @spec get_machine_auth_details(Conn.t()) :: {User.t(), Machine.t()} | nil
  def get_machine_auth_details(%Conn{} = conn) do
    conn.private[@machine_auth_key]
  end

  @doc """
  Get user's API key from user and machine data.

  Connection needs to be given to get the secret key base.
  """
  @spec get_machine_key(Conn.t(), User.t(), Machine.t()) :: String.t()
  def get_machine_key(%Conn{} = conn, %User{} = user, %Machine{} = machine) do
    MessageVerifier.sign(
      form_payload(user.username, machine.id),
      conn.secret_key_base <> machine.api_salt
    )
  end

  @doc """
  Checks if the given password matches the given user's password.
  """
  @spec check_user_password(User.t(), String.t()) :: boolean
  def check_user_password(%User{} = user, password) do
    Bcrypt.verify_pass(password, user.password)
  end

  defp form_payload(username, machine_id) do
    Base.url_encode64(username) <> "##" <> Base.url_encode64(Integer.to_string(machine_id))
  end

  defp unform_payload(payload) do
    with [username, machine] <- String.split(payload, "##"),
         {:ok, username} <- Base.url_decode64(username),
         {:ok, machine} <- Base.url_decode64(machine) do
      {username, machine}
    else
      _ -> :error
    end
  end

  defp split_token(token) do
    # Try new style token split first, then old style
    content =
      case String.split(token, ".") do
        [_, content, _] -> content
        _ -> String.split(token, "##") |> Enum.at(0)
      end

    with {:ok, content} <- Base.decode64(content, padding: false),
         {username, machine} <- unform_payload(content) do
      {username, machine}
    else
      # Given token was malformed in some way
      _ ->
        :error
    end
  end

  defp get_machine(machine_id, user) do
    query =
      from(
        m in Machine,
        where: m.id == ^machine_id and m.user_id == ^user.id and m.active == true
      )

    Repo.one(query)
  end
end
