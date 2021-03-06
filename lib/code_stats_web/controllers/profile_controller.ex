defmodule CodeStatsWeb.ProfileController do
  use CodeStatsWeb, :controller

  alias CodeStats.User
  alias CodeStats.Profile.PermissionUtils
  alias CodeStatsWeb.{AuthUtils, ProfileUtils, Gravatar}

  def my_profile(conn, _params) do
    user = AuthUtils.get_current_user(conn)
    redirect(conn, to: Routes.profile_path(conn, :profile, user.username))
  end

  def profile(conn, %{"username" => username}) do
    with {:ok, user} <- get_user(username),
         true <- PermissionUtils.can_access_profile?(AuthUtils.get_current_user(conn), user) do
      render_or_redirect(conn, user, username, &render_profile/2, :profile)
    else
      _ ->
        conn
        |> put_status(404)
        |> render(CodeStatsWeb.ErrorView, "error_404.html")
    end
  end

  @spec profile_gravatar(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def profile_gravatar(conn, %{"username" => username}) do
    with {:ok, user} <- get_user(username),
         true <- PermissionUtils.can_access_profile?(AuthUtils.get_current_user(conn), user),
         e when not is_nil(e) <- user.gravatar_email,
         hash <- Gravatar.Utils.email_to_hash(user.gravatar_email),
         {:ok, mime, data} = Gravatar.Proxy.get_image(Gravatar.Proxy, hash) do
      conn
      |> put_resp_content_type(mime)
      |> send_resp(200, data)
    else
      _ ->
        conn
        |> send_resp(404, "")
    end
  end

  def profile_api(conn, %{"username" => username}) do
    with {:ok, user} <- get_user(username),
         # Private profiles are not allowed in read API
         false <- user.private_profile do
      render_or_redirect(conn, user, username, &render_profile_api/2, :profile_api)
    else
      _ ->
        conn
        |> put_status(404)
        |> json(%{"error" => "User not found or private."})
    end
  end

  @spec render_profile(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  def render_profile(conn, user) do
    {
      total_xp,
      new_xp,
      date_xps
    } = get_profile_data(user)

    dates_list = Map.to_list(date_xps)

    {last_day, _} =
      try do
        Enum.max_by(dates_list, fn {a, _} -> Date.to_erl(a) end)
      rescue
        Enum.EmptyError ->
          {nil, 0}
      end

    conn
    |> assign(:title, user.username)
    |> assign(:user, user)
    |> assign(:total_xp, total_xp)
    |> assign(:last_day_coded, last_day)
    |> assign(:total_new_xp, new_xp)
    |> render("profile.html")
  end

  @spec render_profile_api(Plug.Conn.t(), User.t()) :: Plug.Conn.t()
  def render_profile_api(conn, user) do
    {
      total_xp,
      new_xp,
      language_xps,
      new_language_xps,
      machine_xps,
      new_machine_xps,
      date_xps
    } = get_api_profile_data(user)

    # Transform data into JSON serializable formats and combine XPs with
    # recent XPs
    serialize_xps = fn xps, new_xps ->
      xps
      |> Enum.map(fn {key, value} ->
        {key.name, %{"xps" => value, "new_xps" => Map.get(new_xps, key.id, 0)}}
      end)
      |> Map.new()
    end

    serialize_date_xps = fn xps ->
      xps
      |> Map.to_list()
      |> Enum.map(fn {key, value} -> {Date.to_iso8601(key), value} end)
      |> Map.new()
    end

    conn
    |> put_status(200)
    |> json(%{
      "user" => user.username,
      "total_xp" => total_xp,
      "new_xp" => new_xp,
      "languages" => serialize_xps.(language_xps, new_language_xps),
      "machines" => serialize_xps.(machine_xps, new_machine_xps),
      "dates" => serialize_date_xps.(date_xps)
    })
  end

  def export_private(conn, _params) do
    user = AuthUtils.get_current_user(conn)

    data =
      [
        ["username", "email", "private_profile", "last_cached", "cache"],
        [user.username, user.email, user.private_profile, user.last_cached, inspect(user.cache)]
      ]
      |> CSV.encode(separator: ?;, delimiter: "\n")
      |> Enum.to_list()
      |> to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"private.csv\"")
    |> send_resp(200, data)
  end

  defp get_profile_data(%User{} = user) do
    date_xps = User.CacheUtils.unformat_cache_from_db(user.cache).dates

    total_xp = Enum.reduce(date_xps, 0, fn {_, amount}, acc -> acc + amount end)
    latest_xp_since = get_since_datetime()
    new_xp = ProfileUtils.get_xps_since(user, latest_xp_since)

    {total_xp, new_xp, date_xps}
  end

  defp get_api_profile_data(%User{} = user) do
    %{
      languages: language_xps,
      machines: machine_xps,
      dates: date_xps
    } =
      user.cache
      |> User.CacheUtils.unformat_cache_from_db()
      |> ProfileUtils.preload_cache_data(user)

    # Calculate total XP
    total_xp = Enum.reduce(language_xps, 0, fn {_, amount}, acc -> acc + amount end)

    # Get new XP data from last 12 hours
    latest_xp_since = get_since_datetime()
    new_language_xps = ProfileUtils.get_language_xps_since(user, latest_xp_since)
    new_machine_xps = ProfileUtils.get_machine_xps_since(user, latest_xp_since)
    new_xp = Enum.reduce(Map.values(new_language_xps), 0, fn amount, acc -> acc + amount end)

    {
      total_xp,
      new_xp,
      language_xps,
      new_language_xps,
      machine_xps,
      new_machine_xps,
      date_xps
    }
  end

  # Render if username matches, redirect otherwise
  defp render_or_redirect(conn, %User{username: username} = user, input_username, renderer, _)
       when username == input_username do
    renderer.(conn, user)
  end

  defp render_or_redirect(conn, user, _, _, redirect_action) do
    redirect(conn, to: Routes.profile_path(conn, redirect_action, user.username))
  end

  # Fix the username specified in the URL by converting plus characters to spaces.
  # This is not done by Phoenix for some reason.
  defp fix_url_username(username) do
    String.replace(username, "+", " ")
  end

  defp get_user(username) do
    with username <- fix_url_username(username),
         %User{} = user <- User.get_by_username(username, true) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  # Get the datetime to use for "last 12h" filtering
  defp get_since_datetime() do
    now = DateTime.utc_now()
    Calendar.DateTime.subtract!(now, 3600 * ProfileUtils.recent_xp_hours())
  end
end
