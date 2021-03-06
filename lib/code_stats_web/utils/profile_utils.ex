defmodule CodeStatsWeb.ProfileUtils do
  @moduledoc """
  Profile related utilities.
  """

  import Ecto.Query, only: [from: 2]

  alias CodeStats.Repo
  alias CodeStats.User
  alias CodeStats.User.{Machine, Pulse, Cache}
  alias CodeStats.Language
  alias CodeStats.XP

  @doc """
  Amount of hours to go back when looking at "recent XP".
  """
  @spec recent_xp_hours() :: Integer.t()
  def recent_xp_hours(), do: 12

  @doc """
  Preload language and machine data to user's cache data, transforming language and machine
  data from maps to lists of tuples.
  """
  @spec preload_cache_data(
          Cache.t(),
          User.t()
        ) :: %{
          languages: [{Language.t(), integer}],
          machines: [{Machine.t(), integer}],
          dates: %{optional(Date.t()) => integer}
        }
  def preload_cache_data(
        %{
          languages: language_xps,
          machines: machine_xps,
          dates: date_xps
        },
        user
      ) do
    %{
      languages: process_language_xps(language_xps),
      machines: process_machine_xps(machine_xps, user),
      dates: date_xps
    }
  end

  @doc """
  Get all XP since `then`.
  """
  @spec get_xps_since(%User{}, %DateTime{}) :: integer
  def get_xps_since(%User{} = user, %DateTime{} = then) do
    from(
      x in XP,
      join: p in Pulse,
      on: p.id == x.pulse_id,
      where: p.user_id == ^user.id and p.sent_at >= ^then,
      select: sum(x.amount)
    )
    |> Repo.one()
    |> case do
      nil -> 0
      amount -> amount
    end
  end

  @doc """
  Get all XP per language accumulated since `then`.
  """
  @spec get_language_xps_since(%User{}, %DateTime{}) :: %{}
  def get_language_xps_since(user, then) do
    xps_q =
      from(
        x in XP,
        join: p in Pulse,
        on: p.id == x.pulse_id,
        join: l in Language,
        on: l.id == x.language_id,
        where: p.user_id == ^user.id and p.sent_at >= ^then,
        select: {l, x.amount}
      )

    case Repo.all(xps_q) do
      nil ->
        %{}

      ret ->
        Enum.reduce(ret, %{}, fn {language, xp}, acc ->
          amount = Map.get(acc, language.id, 0) + xp
          Map.put(acc, language.id, amount)
        end)
    end
  end

  @doc """
  Get all XP per machine since `then`.
  """
  @spec get_machine_xps_since(%User{}, %DateTime{}) :: %{}
  def get_machine_xps_since(user, then) do
    new_xps_q =
      from(
        m in Machine,
        join: p in Pulse,
        on: m.id == p.machine_id,
        join: x in XP,
        on: p.id == x.pulse_id,
        where: m.user_id == ^user.id and p.sent_at >= ^then and m.active == true,
        group_by: m.id,
        order_by: [desc: sum(x.amount)],
        select: {m, sum(x.amount)}
      )

    case Repo.all(new_xps_q) do
      nil ->
        %{}

      ret ->
        Enum.reduce(ret, %{}, fn {machine, amount}, acc ->
          Map.put(acc, machine.id, amount)
        end)
    end
  end

  @spec process_language_xps(%{optional(integer) => integer}) :: [{Language.t(), integer}]
  defp process_language_xps(language_xps) do
    language_xps = Map.to_list(language_xps)

    language_ids = Enum.map(language_xps, fn {id, _} -> id end)

    language_q =
      from(
        l in Language,
        where: l.id in ^language_ids,
        select: {l.id, l}
      )

    languages = Repo.all(language_q) |> Map.new()

    Enum.map(language_xps, fn {id, amount} ->
      {Map.get(languages, id), amount}
    end)
  end

  @spec process_machine_xps(%{optional(integer) => integer}, User.t()) :: [{Machine.t(), integer}]
  defp process_machine_xps(machine_xps, user) do
    machine_xps = Map.to_list(machine_xps)

    machine_q =
      from(
        m in Machine,
        where: m.user_id == ^user.id and m.active == true,
        select: {m.id, m}
      )

    machines = Repo.all(machine_q) |> Map.new()

    # Filter out machines that exist in cache but not in DB (if machine was just deleted)
    # and cache was not regenerated yet
    Enum.map(machine_xps, fn {id, amount} ->
      {Map.get(machines, id), amount}
    end)
    |> Enum.filter(fn
      {nil, _} -> false
      _ -> true
    end)
  end
end
