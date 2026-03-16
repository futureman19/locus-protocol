defmodule Locus.Transaction do
  @moduledoc """
  OP_RETURN encoding and decoding for the territory-centric protocol.

  All protocol data is stored on-chain using OP_RETURN outputs with
  MessagePack-encoded payloads.

  ## Wire Format

      OP_RETURN OP_PUSHDATA2 <total_len:2>
        "locus"              # Protocol prefix (5 bytes)
        <version:2>          # Version (uint16 BE)
        <type:1>             # Transaction type (uint8)
        <payload_len:2>      # Payload length (uint16 BE)
        <payload:variable>   # MessagePack-encoded data

  ## Transaction Types

      0x10: CITY_FOUND        — Found a new city
      0x11: CITY_JOIN          — Citizen joins a city
      0x12: CITY_LEAVE         — Citizen leaves a city
      0x13: TERRITORY_CLAIM    — Claim territory
      0x14: TERRITORY_RELEASE  — Release territory
      0x15: TERRITORY_TRANSFER — Transfer territory
      0x16: PROPOSAL_CREATE    — Create governance proposal
      0x17: PROPOSAL_VOTE      — Vote on proposal
      0x18: UBI_CLAIM          — Claim UBI distribution
      0x19: STAKE_LOCK         — Lock BSV stake
      0x1A: STAKE_UNLOCK       — Unlock matured stake
      0x1B: STAKE_EMERGENCY    — Emergency unlock with penalty
      0x1C: LOCK_TO_MINT       — Lock BSV, mint LOCUS tokens
      0x1D: TOKEN_REDEEM       — Redeem LOCUS tokens for BSV
  """

  @protocol_prefix "locus"
  @version <<0, 1>>

  @type_codes %{
    city_found:         0x10,
    city_join:          0x11,
    city_leave:         0x12,
    territory_claim:    0x13,
    territory_release:  0x14,
    territory_transfer: 0x15,
    proposal_create:    0x16,
    proposal_vote:      0x17,
    ubi_claim:          0x18,
    stake_lock:         0x19,
    stake_unlock:       0x1A,
    stake_emergency:    0x1B,
    lock_to_mint:       0x1C,
    token_redeem:       0x1D
  }

  @reverse_type_codes Map.new(@type_codes, fn {k, v} -> {v, k} end)

  # ---------------------------------------------------------------------------
  # Encoding
  # ---------------------------------------------------------------------------

  @doc """
  Encode a protocol transaction into an OP_RETURN script.

  ## Parameters

    - `type` — Transaction type atom (e.g., `:city_found`)
    - `payload` — Map of data to encode as MessagePack

  ## Examples

      iex> {:ok, script} = Locus.Transaction.encode(:city_found, %{name: "Genesis", territory: <<1::128>>})
      iex> is_binary(script)
      true
  """
  @spec encode(atom(), map()) :: {:ok, binary()} | {:error, atom()}
  def encode(type, payload) when is_atom(type) and is_map(payload) do
    case Map.get(@type_codes, type) do
      nil ->
        {:error, :unknown_type}

      type_byte ->
        payload_binary = Msgpax.pack!(payload, iodata: false)
        payload_len = byte_size(payload_binary)
        total_push = 5 + 2 + 1 + 2 + payload_len

        script = <<
          0x6a,                       # OP_RETURN
          0x4d,                       # OP_PUSHDATA2
          total_push::little-16,      # Total push length
          @protocol_prefix::binary,   # "locus" (5 bytes)
          @version::binary,           # Version (2 bytes)
          type_byte::8,               # Type code (1 byte)
          payload_len::big-16,        # Payload length (2 bytes BE)
          payload_binary::binary      # MessagePack payload
        >>

        {:ok, script}
    end
  end

  @doc """
  Decode an OP_RETURN script into protocol data.

  Returns `{:ok, %{type: atom, version: string, data: map}}` or `{:error, reason}`.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, atom()}
  def decode(script) when is_binary(script) do
    with {:ok, data} <- extract_pushdata(script),
         {:ok, parsed} <- parse_protocol_data(data) do
      {:ok, parsed}
    end
  end

  # ---------------------------------------------------------------------------
  # Payload Builders
  # ---------------------------------------------------------------------------

  @doc "Build a CITY_FOUND OP_RETURN script."
  @spec build_city_found(String.t(), binary(), binary(), non_neg_integer(), keyword()) ::
    {:ok, binary()}
  def build_city_found(name, territory_id, founder_pubkey, stake_amount, opts \\ []) do
    payload = %{
      "name" => name,
      "territory" => territory_id,
      "founder" => Base.encode16(founder_pubkey, case: :lower),
      "stake" => stake_amount,
      "ts" => Keyword.get(opts, :timestamp, System.system_time(:second))
    }

    encode(:city_found, payload)
  end

  @doc "Build a CITY_JOIN OP_RETURN script."
  @spec build_city_join(binary(), binary(), non_neg_integer()) :: {:ok, binary()}
  def build_city_join(city_id, citizen_pubkey, stake_amount) do
    encode(:city_join, %{
      "city" => Base.encode16(city_id, case: :lower),
      "citizen" => Base.encode16(citizen_pubkey, case: :lower),
      "stake" => stake_amount,
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a CITY_LEAVE OP_RETURN script."
  @spec build_city_leave(binary(), binary()) :: {:ok, binary()}
  def build_city_leave(city_id, citizen_pubkey) do
    encode(:city_leave, %{
      "city" => Base.encode16(city_id, case: :lower),
      "citizen" => Base.encode16(citizen_pubkey, case: :lower),
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a TERRITORY_CLAIM OP_RETURN script."
  @spec build_territory_claim(binary(), binary(), binary()) :: {:ok, binary()}
  def build_territory_claim(territory_id, city_id, claimer_pubkey) do
    encode(:territory_claim, %{
      "territory" => Base.encode16(territory_id, case: :lower),
      "city" => Base.encode16(city_id, case: :lower),
      "claimer" => Base.encode16(claimer_pubkey, case: :lower),
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a TERRITORY_RELEASE OP_RETURN script."
  @spec build_territory_release(binary(), binary()) :: {:ok, binary()}
  def build_territory_release(territory_id, owner_pubkey) do
    encode(:territory_release, %{
      "territory" => Base.encode16(territory_id, case: :lower),
      "owner" => Base.encode16(owner_pubkey, case: :lower),
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a TERRITORY_TRANSFER OP_RETURN script."
  @spec build_territory_transfer(binary(), binary(), binary()) :: {:ok, binary()}
  def build_territory_transfer(territory_id, from_pubkey, to_pubkey) do
    encode(:territory_transfer, %{
      "territory" => Base.encode16(territory_id, case: :lower),
      "from" => Base.encode16(from_pubkey, case: :lower),
      "to" => Base.encode16(to_pubkey, case: :lower),
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a PROPOSAL_CREATE OP_RETURN script."
  @spec build_proposal_create(binary(), binary(), map()) :: {:ok, binary()}
  def build_proposal_create(city_id, proposer_pubkey, proposal_params) do
    encode(:proposal_create, %{
      "city" => Base.encode16(city_id, case: :lower),
      "proposer" => Base.encode16(proposer_pubkey, case: :lower),
      "type" => Atom.to_string(proposal_params[:proposal_type]),
      "title" => proposal_params[:title] || "",
      "params" => proposal_params[:params] || %{},
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a PROPOSAL_VOTE OP_RETURN script."
  @spec build_proposal_vote(binary(), binary(), boolean()) :: {:ok, binary()}
  def build_proposal_vote(proposal_id, voter_pubkey, approve?) do
    encode(:proposal_vote, %{
      "proposal" => Base.encode16(proposal_id, case: :lower),
      "voter" => Base.encode16(voter_pubkey, case: :lower),
      "approve" => approve?,
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a UBI_CLAIM OP_RETURN script."
  @spec build_ubi_claim(binary(), binary()) :: {:ok, binary()}
  def build_ubi_claim(city_id, citizen_pubkey) do
    encode(:ubi_claim, %{
      "city" => Base.encode16(city_id, case: :lower),
      "citizen" => Base.encode16(citizen_pubkey, case: :lower),
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a STAKE_LOCK OP_RETURN script."
  @spec build_stake_lock(binary(), binary(), non_neg_integer(), non_neg_integer()) ::
    {:ok, binary()}
  def build_stake_lock(city_id, staker_pubkey, amount, lock_height) do
    encode(:stake_lock, %{
      "city" => Base.encode16(city_id, case: :lower),
      "staker" => Base.encode16(staker_pubkey, case: :lower),
      "amount" => amount,
      "lock_h" => lock_height,
      "ts" => System.system_time(:second)
    })
  end

  @doc "Build a LOCK_TO_MINT OP_RETURN script."
  @spec build_lock_to_mint(binary(), binary(), non_neg_integer()) :: {:ok, binary()}
  def build_lock_to_mint(city_id, locker_pubkey, bsv_amount) do
    encode(:lock_to_mint, %{
      "city" => Base.encode16(city_id, case: :lower),
      "locker" => Base.encode16(locker_pubkey, case: :lower),
      "amount" => bsv_amount,
      "ts" => System.system_time(:second)
    })
  end

  @doc "Get the type code map."
  @spec type_codes() :: map()
  def type_codes, do: @type_codes

  # ---------------------------------------------------------------------------
  # Private: Decoding
  # ---------------------------------------------------------------------------

  defp extract_pushdata(<<0x6a, 0x4c, len, data::binary-size(len), _::binary>>),
    do: {:ok, data}

  defp extract_pushdata(<<0x6a, 0x4d, len::little-16, data::binary-size(len), _::binary>>),
    do: {:ok, data}

  defp extract_pushdata(<<0x6a, len, data::binary-size(len), _::binary>>) when len <= 0x4b,
    do: {:ok, data}

  defp extract_pushdata(_), do: {:error, :invalid_script}

  defp parse_protocol_data(<<
    "locus",
    major, minor,
    type_byte,
    payload_len::big-16,
    payload::binary-size(payload_len),
    _::binary
  >>) do
    case Map.get(@reverse_type_codes, type_byte) do
      nil ->
        {:error, :unknown_type}

      type ->
        case Msgpax.unpack(payload) do
          {:ok, data} ->
            {:ok, %{
              type: type,
              version: "#{major}.#{minor}",
              data: data
            }}

          {:error, _} ->
            {:error, :invalid_payload}
        end
    end
  end

  defp parse_protocol_data(_), do: {:error, :not_locus_protocol}
end
