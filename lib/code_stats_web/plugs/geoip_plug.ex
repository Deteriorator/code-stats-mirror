defmodule CodeStatsWeb.GeoIPPlug do
  @moduledoc """
  Plug for adding GeoIP information about user to conn.

  Contains also utility functions for dealing with the GeoIP information.
  """

  alias Geolix.Adapter.MMDB2

  @geoip_key :_codestats_geoip_data

  # Round to this many decimal places to prevent being too accurate and preserve privacy
  @accuracy 1

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    put_private(conn, @geoip_key, Geolix.lookup(conn.remote_ip))
  end

  @doc """
  Get user's geoip coordinates from conn, if available, nil otherwise.
  """
  def get_coords(conn) do
    case conn.private[@geoip_key] do
      %{
        city: %MMDB2.Result.City{
          location: %MMDB2.Record.Location{
            latitude: lat,
            longitude: lon
          }
        }
      } ->
        %{
          lat: Float.round(lat, @accuracy),
          lon: Float.round(lon, @accuracy)
        }

      _ ->
        nil
    end
  end
end
