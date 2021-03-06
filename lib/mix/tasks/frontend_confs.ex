defmodule CodeStats.FrontendConfs do
  @moduledoc """
  Project specific paths and other stuff for Code::Stats frontend.
  """

  @doc """
  Get absolute path to root directory of project.
  """
  def proj_path() do
    Path.expand("../../../", __DIR__)
  end

  @doc """
  Get absolute path to node_modules.
  """
  def node_path() do
    Path.join([proj_path(), "assets", "node_modules"])
  end

  @doc """
  Get absolute path to binary installed with npm.
  """
  def node_bin(executable), do: Path.join([node_path(), ".bin", executable])

  @doc """
  Get absolute path to source directory for frontend builds.
  """
  def base_src_path(), do: Path.join([proj_path(), "assets"])

  @doc """
  Get absolute path to target directory for frontend build.
  """
  def base_dist_path(), do: Path.join([proj_path(), "priv", "static"])

  def js_path(), do: Path.join([base_src_path(), "js"])
  def css_path(), do: Path.join([base_src_path(), "css"])
  def assets_path(), do: Path.join([base_src_path(), "assets"])
end
