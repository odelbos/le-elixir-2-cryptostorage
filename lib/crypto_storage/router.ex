defmodule CryptoStorage.Router do

  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "Welcome to Crypto Storage!")
  end
end
