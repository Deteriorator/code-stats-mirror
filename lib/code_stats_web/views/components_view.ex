defmodule CodeStatsWeb.ComponentsView do
  use CodeStatsWeb, :view

  @moduledoc """
  A "view" to group related EEx components and methods.
  """

  def get_xp_bar_widths(total_xp, new_xp) do
    level = get_level(total_xp)
    current_level_xp = get_next_level_xp(level - 1)

    have_xp = total_xp - current_level_xp

    if have_xp > new_xp do
      {
        get_level_progress(total_xp - new_xp),
        get_level_progress(total_xp) - get_level_progress(total_xp - new_xp)
      }
    else
      {
        0,
        get_level_progress(total_xp)
      }
    end
  end
end
