defmodule HlsDemo do
  use Application

  def start(_, _) do
    webserver = {Bandit, plug: MyWebRouter, port: 4000}
    Supervisor.start_link([webserver], strategy: :one_for_one)
  end
end
