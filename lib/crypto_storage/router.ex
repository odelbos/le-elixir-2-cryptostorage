defmodule CryptoStorage.Router do

  use Plug.Router

  alias CryptoStorage.ConfigKV

  plug :match
  plug :dispatch

  get "/" do
    conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "Welcome to Crypto Storage!")
  end

  # TODO : Temporary route to test ConfigKV
  # (it will be removed soon)
  get "/config" do
    content = ""
      |> Kernel.<>("read size   : #{ConfigKV.get :read_size}\n")
      |> Kernel.<>("blocksize   : #{ConfigKV.get :block_size}\n")
      |> Kernel.<>("blocks path : #{ConfigKV.get :blocks_path}\n")
      |> Kernel.<>("files path  : #{ConfigKV.get :files_path}\n")
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, content)
  end
end
