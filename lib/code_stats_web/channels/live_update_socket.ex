defmodule CodeStatsWeb.LiveUpdateSocket do
  use Phoenix.Socket

  alias CodeStats.User

  # Maximum age of token that is accepted. We want people to be able to leave the site open and be able to reconnect
  # for a reasonable time but not use their token forever
  @token_max_age 3 * 30 * 86400

  ## Channels
  channel("users:*", CodeStatsWeb.ProfileChannel)
  channel("frontpage", CodeStatsWeb.FrontpageChannel)

  ## Transports
  transport(:websocket, Phoenix.Transports.WebSocket)
  # transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(%{"token" => token}, socket) do
    with %User{} = user <- check_token(socket, token) do
      {:ok, assign(socket, :user_id, user.id)}
    else
      # Invalid token was given, forbid user instead of allowing as unauthed
      _ ->
        :error
    end
  end

  # If user doesn't have token or has invalid params, they are unauthed
  def connect(_params, socket) do
    {:ok, assign(socket, :user_id, nil)}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     CodeStats.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil

  # Check that given token is valid, return user or nil if invalid
  defp check_token(socket, token) do
    with {:ok, data} <- Phoenix.Token.verify(socket, "user", token, max_age: @token_max_age),
         %User{} = user <- User.get_by_username(data) do
      user
    else
      _ -> nil
    end
  end
end
