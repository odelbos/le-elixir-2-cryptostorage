defmodule CryptoStorage.Router do
  require Logger
  use Plug.Router

  alias CryptoStorage.Plug.VerifySetup
  alias CryptoStorage.Settings
  alias CryptoStorage.Utils
  alias CryptoBlocks.Crypto

  plug VerifySetup
  plug :match
  plug :dispatch

  get "/" do
    conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "Welcome to Crypto Storage!")
  end

  # TODO : Temporary route to test Settings
  # (it will be removed soon)
  get "/config" do
    content = ""
      |> Kernel.<>("read size   : #{Settings.get :read_size}\n")
      |> Kernel.<>("blocksize   : #{Settings.get :block_size}\n")
      |> Kernel.<>("blocks path : #{Settings.get :blocks_path}\n")
      |> Kernel.<>("files path  : #{Settings.get :files_path}\n")
    conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, content)
  end

  post "/setup" do
    {:ok, payload, new_conn} = read_body conn
    try do
      [b64_storage_key, b64_time, b64_sig] = String.split payload, "."
      sig = Base.decode64! b64_sig, padding: false

      # Get RSA public key
      der_pub_key = Settings.get(:pub_key) |> Base.decode64!(padding: false)
      pub_key = :public_key.der_decode :RSAPublicKey, der_pub_key

      # Veirfy data signature
      data = b64_storage_key <> "." <> b64_time
      if :public_key.verify data, :sha256, sig, pub_key do
        time = b64_time |> Base.decode64!(padding: false) |> String.to_integer()
        # Verify if timing is ok
        if time - :os.system_time(:seconds) <= 0 do
          raise "Bad timing"
        end

        # Decrypt and store the storage key in settings
        storage_key = Base.decode64!(b64_storage_key, padding: false)
          |> :public_key.decrypt_public(pub_key)

        Settings.set :storage_key, storage_key

        Logger.info "Setup done"
        new_conn
          |> put_resp_content_type("text/plain")
          |> send_resp(:ok, "ok")
      else
        Logger.error "Error - Bad signature"
        new_conn
          |> put_resp_content_type("text/plain")
          |> send_resp(:unprocessable_entity, "Unprocessable Entity")
      end
    rescue
      _e ->
        Logger.error "Setup error"
        new_conn
          |> put_resp_content_type("text/plain")
          |> send_resp(:unprocessable_entity, "Unprocessable Entity")
    end
  end

  get "/id/:id" do
    try do
      # Read blocks description
      files_path = Settings.get :files_path
      filepath = Path.join [files_path, id]

      if File.exists? filepath do
        data = File.read! filepath
        <<iv::128, tag::128, encrypted_blocks::binary>> = data
        iv = <<iv::128>>
        tag = <<tag::128>>
        # Decrypt and unpack blocks
        blocks = Crypto.decrypt(encrypted_blocks, Settings.get(:storage_key), iv, tag)
          |> CryptoBlocks.Utils.unpack()

        new_conn = conn
          |> put_resp_header("Content-Type", "application/octet-stream")
          |> put_resp_header("Content-Disposition","attachment; filename=\"#{id}\"")
          |> send_chunked(200)
        send_blocks new_conn, blocks
      else
        conn
          |> send_resp(404, "404 Not Found")
      end
    rescue
      _e ->
        Logger.error "Cannot get file"
        conn
          |> put_resp_content_type("text/plain")
          |> send_resp(:unprocessable_entity, "Unprocessable Entity")
    end
  end

  post "/" do
    # Compute block size based on content-length
    [value | _] = get_req_header conn, "content-length"
    content_length = String.to_integer value
    block_size = Utils.compute_block_size content_length
    # Get some setting values
    blocks_path = Settings.get :blocks_path
    files_path = Settings.get :files_path

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

    # Pack and encryptthe blocks description
    packed_blocks = CryptoBlocks.Utils.pack blocks
    {iv, tag, encrypted_blocks} =
      Crypto.encrypt packed_blocks, Settings.get(:storage_key)

    # Write blocks description to disk
    id = generate_id files_path
    filepath = Path.join [files_path, id]
    File.write filepath, iv <> tag <> encrypted_blocks, [:binary, :raw]

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
    rsize = Settings.get :read_size
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
    rsize = Settings.get :read_size
    data_size = byte_size data
    new_struct = CryptoBlocks.write struct, data
    new_hstate = :crypto.hash_update hstate, data
    result = read_body conn, length: rsize, read_length: rsize
    do_make_blocks result, new_struct, new_hstate, read_bytes + data_size
  end

  # -----

  defp send_blocks(conn, []), do: conn

  defp send_blocks(conn, [block | rest]) do
    blocks_path = Settings.get :blocks_path
    data = CryptoBlocks.read_block block, blocks_path
    {:ok, new_conn} = chunk conn, data
    send_blocks new_conn, rest
  end
end
