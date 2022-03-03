defmodule CryptoStorage.Router do

  require Logger

  use Plug.Router

  alias CryptoStorage.ConfigKV
  alias CryptoStorage.Utils

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

  get "/id/:id" do
    # Read the blocks description
    files_path = ConfigKV.get :files_path
    filepath = Path.join [files_path, id]

    if File.exists? filepath do
      {:ok, data} = File.read filepath
      # Unpack blocks
      blocks = CryptoBlocks.Utils.unpack data

      new_conn = conn
        |> put_resp_header("Content-Type", "application/octet-stream")
        |> put_resp_header("Content-Disposition","attachment; filename=\"#{id}\"")
        |> send_chunked(200)

      send_blocks new_conn, blocks
    else
      conn
        |> send_resp(404, "404 Not Found")
    end
  end

  post "/" do
    # Compute block size based on content-length
    [value | _] = get_req_header conn, "content-length"
    content_length = String.to_integer value
    block_size = Utils.compute_block_size content_length
    # Get some config values
    blocks_path = ConfigKV.get :blocks_path
    files_path = ConfigKV.get :files_path

    Logger.debug "Content-Length : #{content_length} bytes"
    Logger.debug "Block size : #{block_size} bytes"

    # Read the request body and generate the encrypted blocks
    struct = %CryptoBlocks{storage: blocks_path, size: block_size}
    {:ok, blocks, new_conn, hash, read_bytes} = make_blocks conn, struct

    Logger.debug "Total read : #{read_bytes} bytes"
    Logger.debug "Nb blocks  : #{length(blocks)}"

    # Get a hash of the binary stored inside blocks
    blocks_hash = CryptoBlocks.hash blocks, blocks_path

    Logger.debug "File hash   : #{hash}"
    Logger.debug "Blocks hash : #{blocks_hash}"
    if blocks_hash == hash, do: Logger.debug "Hash are matching !"

    #
    # TODO : if read_bytes != content_length

    # TODO : if blocks_hash != hash
    #

    # Pack the blocks description
    packed_blocks = CryptoBlocks.Utils.pack blocks

    # Write blocks description to disk
    id = generate_id files_path
    filepath = Path.join [files_path, id]
    File.write filepath, packed_blocks, [:binary, :raw]

    Logger.info "Post file : #{id}"

    new_conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, "{\"id\":\"#{id}\"}")
  end

  # --------------------------------------------------------------
  # Helper functions
  # --------------------------------------------------------------
  defp generate_id(path) do
    id = :crypto.strong_rand_bytes(100) |> :erlang.md5 |> Base.encode16(case: :lower)
    filepath = Path.join [path, id]
    if File.exists? filepath do
      generate_id path
    else
      id
    end
  end

  # -----

  defp make_blocks(conn, struct) do
    rsize = ConfigKV.get :read_size
    # Compute a sha256 of the received data from the conn
    # ()usefull to veirfy the integrety of the blocks)
    hstate = :crypto.hash_init :sha256
    result = read_body conn, length: rsize, read_length: rsize
    do_make_blocks result, struct, hstate, 0
  end

  defp do_make_blocks({:ok, data, conn}, struct, hstate, read_bytes) do
    data_size = byte_size data
    {:ok, blocks} = struct |> CryptoBlocks.write(data) |> CryptoBlocks.final()
    hash = hstate
      |> :crypto.hash_update(data)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)
    {:ok, blocks, conn, hash, read_bytes + data_size}
  end

  defp do_make_blocks({:more, data, conn}, struct, hstate, read_bytes) do
    rsize = ConfigKV.get :read_size
    data_size = byte_size data
    new_struct = CryptoBlocks.write struct, data
    new_hstate = :crypto.hash_update hstate, data
    result = read_body conn, length: rsize, read_length: rsize
    do_make_blocks result, new_struct, new_hstate, read_bytes + data_size
  end

  # -----

  defp send_blocks(conn, []), do: conn

  defp send_blocks(conn, [block | rest]) do
    blocks_path = ConfigKV.get :blocks_path
    data = CryptoBlocks.read_block block, blocks_path
    {:ok, new_conn} = chunk conn, data
    send_blocks new_conn, rest
  end
end
