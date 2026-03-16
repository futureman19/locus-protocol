defmodule Locus.Transaction do
  @moduledoc """
  OP_RETURN encoding and decoding for the territory-centric protocol.

  Per spec 07-transaction-formats.md:

  ## Wire Format

      OP_RETURN "LOCUS" {version:1} {type:1} {payload:variable}

  All payload data uses MessagePack encoding.

  ## Message Types

      0x01  CITY_FOUND          — Create new city
      0x02  CITY_UPDATE         — Update city parameters
      0x03  CITIZEN_JOIN        — Join city as citizen
      0x04  CITIZEN_LEAVE       — Leave city
      0x10  TERRITORY_CLAIM     — Claim territory
      0x11  TERRITORY_RELEASE   — Release territory
      0x12  TERRITORY_TRANSFER  — Transfer ownership
      0x20  OBJECT_DEPLOY       — Deploy /1 object
      0x21  OBJECT_UPDATE       — Update object
      0x22  OBJECT_DESTROY      — Destroy object
      0x30  HEARTBEAT           — Proof of presence
      0x40  GHOST_INVOKE        — Invoke ghost
      0x41  GHOST_PAYMENT       — Payment channel op
      0x50  GOV_PROPOSE         — Governance proposal
      0x51  GOV_VOTE            — Governance vote
      0x52  GOV_EXEC            — Execute proposal
      0x60  UBI_CLAIM           — Claim UBI distribution
  """

  @protocol_prefix "LOCUS"
  @version 0x01

  @type_codes %{
    city_found:         0x01,
    city_update:        0x02,
    citizen_join:       0x03,
    citizen_leave:      0x04,
    territory_claim:    0x10,
    territory_release:  0x11,
    territory_transfer: 0x12,
    object_deploy:      0x20,
    object_update:      0x21,
    object_destroy:     0x22,
    heartbeat:          0x30,
    ghost_invoke:       0x40,
    ghost_payment:      0x41,
    gov_propose:        0x50,
    gov_vote:           0x51,
    gov_exec:           0x52,
    ubi_claim:          0x60
  }

  @reverse_codes Map.new(@type_codes, fn {k, v} -> {v, k} end)

  # ---------------------------------------------------------------------------
  # Encoding
  # ---------------------------------------------------------------------------

  @doc """
  Encode a protocol message into an OP_RETURN script.

  Per spec 07-transaction-formats.md:
      OP_RETURN "LOCUS" {version:1} {type:1} {msgpack payload}

  ## Examples

      iex> {:ok, script} = Locus.Transaction.encode(:city_found, %{"name" => "Neo-Tokyo"})
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

        # Protocol data: "LOCUS" + version + type + payload
        protocol_data = <<
          @protocol_prefix::binary,
          @version::8,
          type_byte::8,
          payload_binary::binary
        >>

        total_len = byte_size(protocol_data)

        # OP_RETURN with appropriate pushdata opcode
        script = cond do
          total_len <= 0x4B ->
            <<0x6a, total_len::8, protocol_data::binary>>

          total_len <= 0xFF ->
            <<0x6a, 0x4c, total_len::8, protocol_data::binary>>

          true ->
            <<0x6a, 0x4d, total_len::little-16, protocol_data::binary>>
        end

        {:ok, script}
    end
  end

  @doc """
  Decode an OP_RETURN script into protocol data.

  Returns `{:ok, %{type: atom, version: integer, data: map}}`.
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, atom()}
  def decode(script) when is_binary(script) do
    with {:ok, data} <- extract_pushdata(script),
         {:ok, parsed} <- parse_protocol_data(data) do
      {:ok, parsed}
    end
  end

  # ---------------------------------------------------------------------------
  # Payload Builders (per spec 07-transaction-formats.md schemas)
  # ---------------------------------------------------------------------------

  @doc "Build CITY_FOUND (0x01) payload."
  @spec build_city_found(map()) :: {:ok, binary()}
  def build_city_found(params) do
    encode(:city_found, %{
      "name" => params[:name],
      "description" => params[:description] || "",
      "location" => %{
        "lat" => params[:lat],
        "lng" => params[:lng],
        "h3_res7" => params[:h3_res7] || ""
      },
      "founder_pubkey" => hex(params[:founder_pubkey]),
      "policies" => params[:policies] || %{},
      "signature" => hex(params[:signature] || "")
    })
  end

  @doc "Build CITIZEN_JOIN (0x03) payload."
  @spec build_citizen_join(binary(), binary()) :: {:ok, binary()}
  def build_citizen_join(city_id, citizen_pubkey) do
    encode(:citizen_join, %{
      "city_id" => hex(city_id),
      "citizen_pubkey" => hex(citizen_pubkey),
      "timestamp" => System.system_time(:second)
    })
  end

  @doc "Build TERRITORY_CLAIM (0x10) payload."
  @spec build_territory_claim(map()) :: {:ok, binary()}
  def build_territory_claim(params) do
    encode(:territory_claim, %{
      "level" => params[:level],
      "location" => params[:h3_index] || "",
      "owner_pubkey" => hex(params[:owner_pubkey]),
      "stake_amount" => params[:stake_amount],
      "lock_height" => params[:lock_height],
      "parent_city" => hex(params[:parent_city] || ""),
      "metadata" => params[:metadata] || %{}
    })
  end

  @doc "Build TERRITORY_TRANSFER (0x12) payload."
  @spec build_territory_transfer(binary(), binary(), binary(), non_neg_integer()) ::
    {:ok, binary()}
  def build_territory_transfer(territory_id, from_pubkey, to_pubkey, price \\ 0) do
    encode(:territory_transfer, %{
      "territory_id" => hex(territory_id),
      "from_pubkey" => hex(from_pubkey),
      "to_pubkey" => hex(to_pubkey),
      "price" => price,
      "timestamp" => System.system_time(:second)
    })
  end

  @doc "Build GOV_PROPOSE (0x50) payload."
  @spec build_gov_propose(binary(), binary(), map()) :: {:ok, binary()}
  def build_gov_propose(city_id, proposer_pubkey, params) do
    encode(:gov_propose, %{
      "proposal_type" => proposal_type_code(params[:proposal_type]),
      "scope" => params[:scope] || 1,
      "title" => params[:title] || "",
      "description" => params[:description] || "",
      "actions" => params[:actions] || [],
      "deposit" => params[:deposit] || 10_000_000,
      "proposer_pubkey" => hex(proposer_pubkey),
      "timestamp" => System.system_time(:second)
    })
  end

  @doc "Build GOV_VOTE (0x51) payload."
  @spec build_gov_vote(binary(), binary(), :yes | :no | :abstain) :: {:ok, binary()}
  def build_gov_vote(proposal_id, voter_pubkey, vote) do
    vote_code = case vote do
      :yes -> 1
      :no -> 0
      :abstain -> 2
    end

    encode(:gov_vote, %{
      "proposal_id" => hex(proposal_id),
      "voter_pubkey" => hex(voter_pubkey),
      "vote" => vote_code,
      "timestamp" => System.system_time(:second)
    })
  end

  @doc "Build UBI_CLAIM (0x60) payload."
  @spec build_ubi_claim(binary(), binary(), non_neg_integer()) :: {:ok, binary()}
  def build_ubi_claim(city_id, citizen_pubkey, claim_periods) do
    encode(:ubi_claim, %{
      "city_id" => hex(city_id),
      "citizen_pubkey" => hex(citizen_pubkey),
      "claim_periods" => claim_periods,
      "timestamp" => System.system_time(:second)
    })
  end

  @doc "Build HEARTBEAT (0x30) payload."
  @spec build_heartbeat(map()) :: {:ok, binary()}
  def build_heartbeat(params) do
    encode(:heartbeat, %{
      "heartbeat_type" => params[:heartbeat_type] || 2,
      "entity_id" => hex(params[:entity_id]),
      "location" => params[:h3_index] || "",
      "timestamp" => System.system_time(:second),
      "nonce" => :crypto.strong_rand_bytes(4) |> :binary.decode_unsigned()
    })
  end

  @doc "Build OBJECT_DEPLOY (0x20) payload."
  @spec build_object_deploy(map()) :: {:ok, binary()}
  def build_object_deploy(params) do
    encode(:object_deploy, %{
      "object_type" => Atom.to_string(params[:object_type] || :item),
      "location" => params[:h3_index] || "",
      "owner_pubkey" => hex(params[:owner_pubkey]),
      "stake_amount" => params[:stake_amount] || 0,
      "content_hash" => hex(params[:content_hash] || ""),
      "parent_territory" => hex(params[:parent_territory] || ""),
      "capabilities" => params[:capabilities] || []
    })
  end

  @doc "Get the type codes map."
  def type_codes, do: @type_codes

  # ---------------------------------------------------------------------------
  # Private: Decoding
  # ---------------------------------------------------------------------------

  defp extract_pushdata(<<0x6a, len, data::binary-size(len), _::binary>>)
       when len <= 0x4B, do: {:ok, data}

  defp extract_pushdata(<<0x6a, 0x4c, len, data::binary-size(len), _::binary>>),
    do: {:ok, data}

  defp extract_pushdata(<<0x6a, 0x4d, len::little-16, data::binary-size(len), _::binary>>),
    do: {:ok, data}

  defp extract_pushdata(_), do: {:error, :invalid_script}

  defp parse_protocol_data(<<"LOCUS", version::8, type_byte::8, payload::binary>>) do
    case Map.get(@reverse_codes, type_byte) do
      nil ->
        {:error, :unknown_type}

      type ->
        case Msgpax.unpack(payload) do
          {:ok, data} ->
            {:ok, %{type: type, version: version, data: data}}

          {:error, _} ->
            {:error, :invalid_payload}
        end
    end
  end

  defp parse_protocol_data(_), do: {:error, :not_locus_protocol}

  # Hex encode binary data for MessagePack payloads
  defp hex(data) when is_binary(data) and byte_size(data) > 0 do
    Base.encode16(data, case: :lower)
  end

  defp hex(_), do: ""

  defp proposal_type_code(:parameter_change), do: 0x01
  defp proposal_type_code(:contract_upgrade), do: 0x02
  defp proposal_type_code(:treasury_spend), do: 0x03
  defp proposal_type_code(:constitutional), do: 0x04
  defp proposal_type_code(:emergency), do: 0x05
  defp proposal_type_code(_), do: 0x00
end
