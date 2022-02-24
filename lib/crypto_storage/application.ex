defmodule CryptoStorage.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: CryptoStorage.Router, options: [port: 4554]},
      {CryptoStorage.ConfigKV, []}
    ]

    opts = [strategy: :one_for_one, name: CryptoStorage.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
