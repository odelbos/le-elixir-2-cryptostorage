#
# The block size is progressing from 32 bytes to 30 MB when the input
# binary is between 128 bytes and 8 GB.
# When the input binary is over 8 GB the block size is always 30MB.
#
defmodule CryptoStorage.Utils do
  @kb 1024
  @mb 1024*@kb
  @gb 1024*@mb

  def compute_block_size(bytes) do
    # nb = nb_blocks bytes
    # floor bytes / nb
    floor bytes / nb_blocks(bytes)
  end

  # -----

  def nb_blocks(bytes) when bytes <= 128, do: 4
  def nb_blocks(bytes) when bytes <= 256, do: 6
  def nb_blocks(bytes) when bytes <= 512, do: 8
  def nb_blocks(bytes) when bytes <= @kb, do: 10
  def nb_blocks(bytes) when bytes <= @mb, do: 15
  def nb_blocks(bytes) when bytes <= 10 * @mb, do: 20
  def nb_blocks(bytes) when bytes <= 20 * @mb, do: 30
  def nb_blocks(bytes) when bytes <= 50 * @mb, do: 35
  def nb_blocks(bytes) when bytes <= 100 * @mb, do: 40
  def nb_blocks(bytes) when bytes <= 2 * @gb do
    floor(bytes / ((2*@gb-100*@mb) / 60) + 40)
  end
  def nb_blocks(bytes) when bytes <= 4 * @gb, do: floor(bytes / (20*@mb))
  def nb_blocks(bytes) when bytes <= 8 * @gb, do: floor(bytes / (25*@mb))
  def nb_blocks(bytes), do: floor(bytes / (30*@mb))
end
