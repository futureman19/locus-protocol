defmodule Locus.Chain do
  @moduledoc """
  BSV blockchain interaction for the territory-centric protocol.

  Handles:
  - Broadcasting transactions via ARC (GorillaPool / TAAL)
  - Querying block height
  - Scanning blocks for territory protocol transactions
  - Parsing OP_RETURN outputs for protocol data

  All state is derived from chain — no database.
  """

  use GenServer

  require Logger

  alias BSV.ARC.Client, as: ARCClient
  alias BSV.ARC.Config, as: ARCConfig
  alias BSV.Transaction

  defstruct [
    :arc_client,
    :arc_config,
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

    Logger.info("Locus.Chain (territory) initialized on #{network}")
    {:ok, state}
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Get current blockchain height."
  @spec get_height() :: {:ok, non_neg_integer()} | {:error, term()}
  def get_height do
    GenServer.call(__MODULE__, :get_height)
  end

  @doc "Broadcast a raw transaction hex via ARC."
  @spec broadcast(binary()) :: {:ok, map()} | {:error, term()}
  def broadcast(tx_hex) when is_binary(tx_hex) do
    GenServer.call(__MODULE__, {:broadcast, tx_hex})
  end

  @doc "Broadcast a Transaction struct."
  @spec broadcast(Transaction.t()) :: {:ok, map()} | {:error, term()}
  def broadcast(%Transaction{} = tx) do
    tx
    |> Transaction.to_binary()
    |> Base.encode16(case: :lower)
    |> broadcast()
  end

  @doc "Scan a range of blocks for territory protocol transactions."
  @spec scan_range(non_neg_integer(), non_neg_integer()) ::
    {:ok, [map()]} | {:error, term()}
  def scan_range(start_height, end_height) do
    GenServer.call(__MODULE__, {:scan_range, start_height, end_height})
  end

  @doc "Get the last scanned block height."
  @spec last_scanned_height() :: non_neg_integer()
  def last_scanned_height do
    GenServer.call(__MODULE__, :last_scanned_height)
  end

  @doc """
  Parse a raw transaction hex for territory protocol data.

  Scans all outputs for OP_RETURN data matching the Locus Protocol prefix.
  """
  @spec parse_transaction(binary()) :: {:ok, map()} | {:error, atom()}
  def parse_transaction(tx_hex) when is_binary(tx_hex) do
    case Base.decode16(tx_hex, case: :mixed) do
      {:ok, binary} ->
        case Transaction.parse(binary) do
          {:ok, tx} -> parse_transaction_outputs(tx)
          {:error, reason} -> {:error, reason}
        end

      :error ->
        {:error, :invalid_hex}
    end
  end

  def parse_transaction(%Transaction{} = tx) do
    parse_transaction_outputs(tx)
  end

  @doc """
  Build a complete transaction with OP_RETURN output.

  Combines a CLTV-locked stake output (if applicable) with the
  protocol OP_RETURN output and optional change.
  """
  @spec build_transaction(keyword()) :: {:ok, map()} | {:error, atom()}
  def build_transaction(opts) do
    type = Keyword.fetch!(opts, :type)
    payload = Keyword.fetch!(opts, :payload)
    funding_utxo = Keyword.fetch!(opts, :funding_utxo)
    owner_pubkey_hash = Keyword.get(opts, :owner_pubkey_hash)
    stake_output = Keyword.get(opts, :stake_output)

    case Locus.Transaction.encode(type, payload) do
      {:ok, op_return_script} ->
        outputs = build_outputs(op_return_script, stake_output)

        # Calculate fee and change
        fee = estimate_fee(outputs)
        input_amount = funding_utxo.satoshis
        output_amount = Enum.reduce(outputs, 0, fn o, acc -> acc + o.satoshis end)
        change = input_amount - output_amount - fee

        outputs = if change > 546 and owner_pubkey_hash do
          outputs ++ [%{satoshis: change, locking_script: owner_pubkey_hash}]
        else
          outputs
        end

        tx = %{
          version: 1,
          inputs: [%{
            txid: funding_utxo.txid,
            vout: funding_utxo.vout,
            script_sig: "",
            sequence: 0xFFFFFFFF
          }],
          outputs: outputs,
          lock_time: 0
        }

        {:ok, tx}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call(:get_height, _from, state) do
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
    Logger.info("Scanning blocks #{start_height} to #{end_height} for territory txs")

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

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp default_arc_endpoint(:mainnet), do: "https://arc.taal.com"
  defp default_arc_endpoint(:testnet), do: "https://arc.gorillapool.io"
  defp default_arc_endpoint(_), do: "https://arc.gorillapool.io"

  defp query_arc_height(_client) do
    # Placeholder — would use JungleBus or block explorer API
    {:ok, 0}
  end

  defp scan_block(_height, _state) do
    # Placeholder — would fetch block via JungleBus and filter for
    # Locus Protocol OP_RETURN outputs
    {:ok, []}
  end

  defp parse_transaction_outputs(%Transaction{} = tx) do
    tx.outputs
    |> Enum.with_index()
    |> Enum.find_value({:error, :no_locus_data}, fn {output, index} ->
      case Locus.Transaction.decode(output.locking_script) do
        {:ok, data} -> {:ok, %{txid: tx.id, vout: index, data: data}}
        _ -> nil
      end
    end)
  end

  defp build_outputs(op_return_script, nil) do
    [%{satoshis: 0, locking_script: op_return_script}]
  end

  defp build_outputs(op_return_script, stake_output) do
    [
      %{satoshis: stake_output.satoshis, locking_script: stake_output.locking_script},
      %{satoshis: 0, locking_script: op_return_script}
    ]
  end

  defp estimate_fee(outputs) do
    # ~1 sat/byte, estimate ~150 bytes base + 34 bytes per output
    base = 150
    output_bytes = length(outputs) * 34
    base + output_bytes
  end
end
