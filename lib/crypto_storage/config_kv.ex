defmodule CryptoStorage.ConfigKV do
  use GenServer

  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{}, name: :config)
  end

  def init(_state) do
    case File.read "./config/settings.json" do
      { :ok, json } ->
        Jason.decode json, keys: :atoms
      _ ->
        {:error, "Cannot read configuration file !"}
    end
  end

  def set(key, value) do
    GenServer.cast :config, {:set, key, value}
  end

  def get(key) do
    GenServer.call :config, {:get, key}
  end

  def handle_cast({:set, key, value}, state) do
    {:noreply, Map.put(state, key, value)}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, state[key], state}
  end
end
