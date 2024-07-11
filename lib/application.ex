defmodule HlsDemo do
  @moduledoc false

  use Application

  def start(_, _) do
   ["priv/iinput", "priv/output", "priv/hls"] |> Enum.each(&File.mkdir/1)
    webserver = {Bandit, plug: MyWebRouter, port: 4000}
    Supervisor.start_link([webserver], strategy: :one_for_one)
  end
end
