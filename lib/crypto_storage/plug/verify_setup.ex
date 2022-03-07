defmodule CryptoStorage.Plug.VerifySetup do
  require Logger

  import Plug.Conn
  alias CryptoStorage.ConfigKV

  def init(options), do: options

  def call(%Plug.Conn{request_path: path} = conn, _opts) do
    conn
      |> check_pub_key()
      |> check_storage_key(path)
  end

  # ------

  defp check_pub_key(conn) do
    if ConfigKV.get(:pub_key) == nil do
      Logger.warn "Public key is missing !"
      conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:service_unavailable, "Service Unavailable")
        |> halt
    else
      conn
    end
  end

  # ------

  defp check_storage_key(conn, "/setup") do
    storage_key = ConfigKV.get :storage_key
    unless storage_key == nil do
      Logger.warn "Access to setup forbidden"
      # Storage key is already configured, we can't override the settings.
      # Access to /setup is now forbiden.
      conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:forbidden, "Forbidden")
        |> halt
    else
      Logger.debug "Access to /setup granted"
      conn
    end
  end

  defp check_storage_key(conn, _path) do
    storage_key = ConfigKV.get :storage_key
    if storage_key == nil do
      Logger.warn "Access to any path are prohibed"
      conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:service_unavailable, "Service Unavailable")
        |> halt
    else
      conn
    end
  end
end
