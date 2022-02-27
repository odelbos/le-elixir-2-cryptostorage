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

  post "/" do
    #
    # TODO : How to compute the block size ?
    # (based on the content-length of the file)
    #
    block_size = ConfigKV.get :block_size
    blocks_path = ConfigKV.get :blocks_path
    files_path = ConfigKV.get :files_path

    content_length = get_req_header conn, "content-length"

    struct = %CryptoBlocks{storage: blocks_path, size: block_size}

    {:ok, blocks, new_conn, hash, count} = make_blocks conn, struct, 0

    size = CryptoBlocks.bytes blocks, blocks_path
    blocks_hash = CryptoBlocks.hash blocks, blocks_path

    #
    # TODO : if size != content_length
    #

    IO.puts "Content Length : #{content_length}"
    IO.puts "Read count : #{count}"
    IO.puts "Blocks size : #{size}"
    IO.puts "Blocks hash : #{blocks_hash}"
    IO.puts "Blocks count : #{length(blocks)}"
    IO.puts "Original hash : #{hash}"
    if blocks_hash == hash do
      IO.puts "--hash are matching !--"
    end

    # Pack and encrypt the blocks description
    packed_blocks = CryptoBlocks.Utils.pack blocks

    # Write blocks description to disk
    id = generate_id files_path
    filepath = Path.join [files_path, id]
    File.write filepath, packed_blocks, [:binary, :raw]

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

  defp make_blocks(conn, struct, count) do
    rsize = ConfigKV.get :read_size
    # Will compute a sha256 of the received data from the conn
    # It will allow to veirfy the integrety of the saved blocks
    hstate = :crypto.hash_init :sha256
    result = Plug.Conn.read_body conn, length: rsize, read_length: rsize
    do_make_blocks result, struct, hstate, count
  end

  defp do_make_blocks({:ok, data, conn}, struct, hstate, count) do
    data_size = byte_size data
    {:ok, blocks} = struct |> CryptoBlocks.write(data) |> CryptoBlocks.final()
    hash = hstate
      |> :crypto.hash_update(data)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)
    {:ok, blocks, conn, hash, count + data_size}
  end

  defp do_make_blocks({:more, data, conn}, struct, hstate, count) do
    rsize = ConfigKV.get :read_size
    data_size = byte_size data
    new_struct = CryptoBlocks.write struct, data
    new_hstate = :crypto.hash_update hstate, data
    result = Plug.Conn.read_body conn, length: rsize, read_length: rsize
    do_make_blocks result, new_struct, new_hstate, count + data_size
  end
end
