defmodule Locus.Chain do
  @moduledoc """
  BSV blockchain interaction using bsv_sdk

  Handles:
  - Querying block height
  - Broadcasting transactions via ARC
  - Scanning blocks for Locus Protocol transactions
  - Parsing OP_RETURN payloads
  """

  use GenServer

  require Logger

  alias BSV.ARC.Client, as: ARCClient
  alias BSV.ARC.Config, as: ARCConfig
  alias BSV.Transaction

  # Protocol constants
  @protocol_prefix "locus"
  @protocol_prefix_hex "0x6c6f637573"
  @version_0_1_0 <<0, 1>>  # Major=0, Minor=1

  # Transaction type codes
  @type_codes %{
    0x01 => :ghost_register,
    0x02 => :ghost_update,
    0x03 => :ghost_retire,
    0x04 => :heartbeat,
    0x05 => :invocation,
    0x06 => :challenge,
    0x07 => :challenge_response,
    0x08 => :stake,
    0x09 => :unstake
  }

  defstruct [
    :arc_client,
    :arc_config,
    :junglebus_client,
    :network,
    :last_scanned_height
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    network = Keyword.get(opts, :network, :testnet)
    arc_endpoint = Keyword.get(opts, :arc_endpoint, default_arc_endpoint(network))
    arc_api_key = Keyword.get(opts, :arc_api_key, "")

    config = %ARCConfig{
      api_key: arc_api_key,
      endpoint: arc_endpoint
    }

    client = ARCClient.new(config)

    state = %__MODULE__{
      arc_client: client,
      arc_config: config,
      network: network,
      last_scanned_height: Keyword.get(opts, :start_height, 0)
    }

    Logger.info("Locus.Chain initialized on #{network}")
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Get current blockchain height
  """
  def get_height do
    GenServer.call(__MODULE__, :get_height)
  end

  @doc """
  Broadcast a raw transaction via ARC
  """
  def broadcast(tx_hex) when is_binary(tx_hex) do
    GenServer.call(__MODULE__, {:broadcast, tx_hex})
  end

  @doc """
  Broadcast a Transaction struct
  """
  def broadcast(%Transaction{} = tx) do
    tx
    |> Transaction.to_binary()
    |> Base.encode16(case: :lower)
    |> broadcast()
  end

  @doc """
  Scan blocks for Locus Protocol transactions
  Returns list of parsed protocol transactions
  """
  def scan_range(start_height, end_height) do
    GenServer.call(__MODULE__, {:scan_range, start_height, end_height})
  end

  @doc """
  Get the last scanned height
  """
  def last_scanned_height do
    GenServer.call(__MODULE__, :last_scanned_height)
  end

  @doc """
  Parse a raw transaction for Locus Protocol data
  """
  def parse_transaction(tx_hex) when is_binary(tx_hex) do
    case Base.decode16(tx_hex, case: :mixed) do
      {:ok, binary} -> parse_transaction_binary(binary)
      :error -> {:error, :invalid_hex}
    end
  end

  def parse_transaction(%Transaction{} = tx) do
    parse_transaction_outputs(tx)
  end

  # ----------------------------------------------------------------------------
  # GenServer Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def handle_call(:get_height, _from, state) do
    # Query ARC for current tip
    case query_arc_height(state.arc_client) do
      {:ok, height} -> {:reply, {:ok, height}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:broadcast, tx_hex}, _from, state) do
    case ARCClient.broadcast(state.arc_client, tx_hex) do
      {:ok, response} ->
        Logger.info("Broadcast successful: #{response.txid}")
        {:reply, {:ok, response}, state}

      {:error, reason} ->
        Logger.error("Broadcast failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:scan_range, start_height, end_height}, _from, state) do
    Logger.info("Scanning blocks #{start_height} to #{end_height}")

    transactions =
      start_height..end_height
      |> Enum.flat_map(fn height ->
        case scan_block(height, state) do
          {:ok, txs} -> txs
          {:error, _} -> []
        end
      end)

    new_state = %{state | last_scanned_height: end_height}
    {:reply, {:ok, transactions}, new_state}
  end

  @impl true
  def handle_call(:last_scanned_height, _from, state) do
    {:reply, state.last_scanned_height, state}
  end

  # ----------------------------------------------------------------------------
  # Private Functions
  # ----------------------------------------------------------------------------

  defp default_arc_endpoint(:mainnet), do: "https://arc.taal.com"
  defp default_arc_endpoint(:testnet), do: "https://arc.gorillapool.io"
  defp default_arc_endpoint(_), do: "https://arc.gorillapool.io"

  defp query_arc_height(_client) do
    # This would use JungleBus or a block explorer API
    # For now, return a placeholder
    # In production: BSV.JungleBus.Client.get_chain_tip()
    {:ok, 0}
  end

  defp scan_block(_height, _state) do
    # This would fetch block via JungleBus or peer connection
    # For now, return empty
    # In production:
    # 1. Fetch block via BSV.JungleBus.Client
    # 2. Parse each transaction
    # 3. Filter for Locus Protocol OP_RETURN outputs
    {:ok, []}
  end

  @doc """
  Parse transaction binary and extract Locus Protocol data
  """
  def parse_transaction_binary(binary) do
    case Transaction.parse(binary) do
      {:ok, tx} -> parse_transaction_outputs(tx)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parse transaction outputs looking for Locus Protocol OP_RETURN
  """
  def parse_transaction_outputs(%Transaction{} = tx) do
    tx.outputs
    |> Enum.with_index()
    |> Enum.find_value({:error, :no_locus_data}, fn {output, index} ->
      case parse_op_return(output.locking_script) do
        {:ok, data} -> {:ok, %{txid: tx.id, vout: index, data: data}}
        _ -> nil
      end
    end)
  end

  @doc """
  Parse an OP_RETURN script for Locus Protocol data
  """
  def parse_op_return(script) when is_binary(script) do
    # OP_RETURN scripts start with 0x6a
    # Then pushdata for protocol prefix (5 bytes: "locus")
    # Then version (2 bytes)
    # Then type (1 byte)
    # Then payload length (2 bytes, big-endian)
    # Then payload

    with {:ok, binary} <- extract_pushdata(script),
         true <- String.starts_with?(binary, @protocol_prefix) do
      parse_payload(binary)
    else
      _ -> {:error, :not_locus_protocol}
    end
  end

  defp extract_pushdata(script) do
    # OP_RETURN = 0x6a
    # Then OP_PUSHDATA1 (0x4c) + 1-byte length + data
    # Or OP_PUSHDATA2 (0x4d) + 2-byte length + data
    # Or direct push (0x01-0x4b) where byte is length

    case script do
      <<0x6a, 0x4c, len, data::binary-size(len), _::binary>> ->
        {:ok, data}

      <<0x6a, 0x4d, len::little-16, data::binary-size(len), _::binary>> ->
        {:ok, data}

      <<0x6a, len, data::binary-size(len), _::binary>> when len <= 0x4b ->
        {:ok, data}

      _ ->
        {:error, :invalid_script}
    end
  end

  defp parse_payload(<<"locus", version::binary-2, type_byte, len::big-16, payload::binary>>) do
    case Map.get(@type_codes, type_byte) do
      nil ->
        {:error, :unknown_type}

      type ->
        # Parse MessagePack payload
        case decode_payload(payload, len) do
          {:ok, data} ->
            {:ok, %{
              protocol: "locus",
              version: version_to_string(version),
              type: type,
              data: data
            }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp parse_payload(_), do: {:error, :invalid_payload}

  defp decode_payload(payload, expected_len) do
    actual_len = byte_size(payload)

    if actual_len >= expected_len do
      data = :binary.part(payload, 0, expected_len)

      # Use Jason for JSON or msgpax for MessagePack
      # For now, return raw binary (actual MessagePack decoding would use msgpax lib)
      {:ok, %{raw: data, decoded: nil}}
    else
      {:error, :truncated_payload}
    end
  end

  defp version_to_string(<<major, minor>>) do
    "#{major}.#{minor}"
  end

  # ----------------------------------------------------------------------------
  # Transaction Building Helpers
  # ----------------------------------------------------------------------------

  @doc """
  Build OP_RETURN output for Locus Protocol transaction
  """
  def build_op_return(type, payload_data) when is_atom(type) do
    type_byte = type_to_byte(type)

    # Encode payload (JSON for now, MessagePack in production)
    payload = Jason.encode!(payload_data)
    payload_len = byte_size(payload)

    # Build script:
    # OP_RETURN <protocol> <version> <type> <len> <payload>
    script = <<
      0x6a,                    # OP_RETURN
      0x4d,                    # OP_PUSHDATA2
      (5 + 2 + 1 + 2 + payload_len)::little-16,  # Total push length
      "locus",                 # Protocol prefix (5 bytes)
      @version_0_1_0::binary,  # Version (2 bytes)
      type_byte,               # Type (1 byte)
      payload_len::big-16,     # Payload length (2 bytes, big-endian)
      payload::binary          # Payload
    >>

    {:ok, script}
  end

  defp type_to_byte(:ghost_register), do: 0x01
  defp type_to_byte(:ghost_update), do: 0x02
  defp type_to_byte(:ghost_retire), do: 0x03
  defp type_to_byte(:heartbeat), do: 0x04
  defp type_to_byte(:invocation), do: 0x05
  defp type_to_byte(:challenge), do: 0x06
  defp type_to_byte(:challenge_response), do: 0x07
  defp type_to_byte(:stake), do: 0x08
  defp type_to_byte(:unstake), do: 0x09
  defp type_to_byte(_), do: 0x00
end
