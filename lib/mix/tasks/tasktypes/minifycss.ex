defmodule CodeStats.BuildTasks.MinifyCSS do
  import MBU.TaskUtils
  import CodeStats.FrontendConfs

  def bin(), do: node_bin("cssnano")

  def args(in_file, out_file) do
    [
      in_file,
      out_file
    ]
  end

  def task(in_file, out_file) do
    bin() |> exec(args(in_file, out_file)) |> listen()

    print_size(out_file, in_file)
  end
end
