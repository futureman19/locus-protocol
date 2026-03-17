defmodule Locus.TxBuilder do
  @moduledoc """
  Transaction builder for Locus Protocol

  Helper functions to construct protocol-compliant transactions.
  """

  alias BSV.{PrivateKey, PublicKey, Script, Transaction}
  alias Locus.{Ghost, Staking}

  require Logger

  # Protocol prefix - TERRITORY-CENTRIC (per spec 07)
  @protocol_prefix "LOCUS"
  @version 0x01

  # Type codes - TERRITORY-CENTRIC PROTOCOL (per spec 07)
  # These MUST match core/lib/locus/transaction.ex
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

  @doc """
  Build a GHOST_REGISTER transaction

  Creates:
  - Output 1: P2SH stake lock (CLTV)
  - Output 2: OP_RETURN with ghost metadata
  - Output 3: Change (optional)
  """
  def build_ghost_register(
    owner_key,
    ghost_params,
    funding_utxo,
    current_height,
    opts \\ []
  ) do
    network = Keyword.get(opts, :network, :testnet)

    # Extract parameters
    name = Keyword.fetch!(ghost_params, :name)
    type = Keyword.fetch!(ghost_params, :type)
    lat = Keyword.fetch!(ghost_params, :lat)
    lng = Keyword.fetch!(ghost_params, :lng)
    stake_amount = Keyword.fetch!(ghost_params, :stake_amount)
    code_hash = Keyword.get(ghost_params, :code_hash, nil)
    code_uri = Keyword.get(ghost_params, :code_uri, nil)
    base_fee = Keyword.get(ghost_params, :base_fee, 1000)
    timeout = Keyword.get(ghost_params, :timeout, 30)
    meta = Keyword.get(ghost_params, :meta, %{})

    # Validate minimum stake
    min_stake = Ghost.min_stake(type)
    if stake_amount < min_stake do
      {:error, "Stake below minimum: #{min_stake} sats required"}
    end

    # Calculate lock height (5 months = 21,600 blocks)
    lock_height = Ghost.lock_height(current_height)

    # Get owner public key
    owner_pubkey = PrivateKey.to_public_key(owner_key)
    owner_pubkey_binary = PublicKey.to_binary(owner_pubkey)
    owner_pubkey_hash = PublicKey.to_hash(owner_pubkey)

    # Build CLTV lock script
    redeem_script = Staking.build_lock_script(lock_height, owner_pubkey_binary)
    p2sh_address = Staking.p2sh_address(redeem_script)

    # Build H3 index from lat/lng
    h3_index = lat_lng_to_h3(lat, lng)

    # Build OP_RETURN payload
    payload = %{
      name: name,
      type: ghost_type_code(type),
      lat: round(lat * 1_000_000),  # microdegrees
      lng: round(lng * 1_000_000),
      h3: h3_index,
      stake_amt: stake_amount,
      lock_blocks: 21_600,
      unlock_h: lock_height,
      owner_pk: Base.encode16(owner_pubkey_binary, case: :lower),
      code_hash: code_hash,
      code_uri: code_uri,
      base_fee: base_fee,
      timeout: timeout,
      meta: meta
    }

    # Build OP_RETURN script
    {:ok, op_return_script} = build_op_return(:ghost_register, payload)

    # Calculate outputs
    outputs = [
      # Stake output (P2SH)
      %{
        satoshis: stake_amount,
        locking_script: p2sh_address
      },
      # OP_RETURN output
      %{
        satoshis: 0,
        locking_script: op_return_script
      }
    ]

    # Calculate fee and add change output if needed
    # Fee estimation: ~200 bytes @ 0.5 sat/byte = 100 sats
    fee = 100
    change_amount = funding_utxo.satoshis - stake_amount - fee

    outputs = if change_amount > 546 do  # Dust limit
      outputs ++ [%{
        satoshis: change_amount,
        locking_script: owner_pubkey_hash  # P2PKH change
      }]
    else
      outputs
    end

    # Build transaction
    tx = %Transaction{
      version: 1,
      inputs: [
        %{
          txid: funding_utxo.txid,
          vout: funding_utxo.vout,
          script_sig: "",  # Will be signed
          sequence: 0xFFFFFFFF
        }
      ],
      outputs: outputs,
      lock_time: 0
    }

    {:ok, %{tx: tx, redeem_script: redeem_script, lock_height: lock_height}}
  end

  @doc """
  Build a HEARTBEAT transaction
  """
  def build_heartbeat(ghost_id, sequence, location, owner_key, funding_utxo) do
    payload = %{
      ghost_id: ghost_id,
      seq: sequence,
      h3: location.h3_index,
      lat: round(location.lat * 1_000_000),
      lng: round(location.lng * 1_000_000),
      ts: System.system_time(:second)
    }

    {:ok, op_return_script} = build_op_return(:heartbeat, payload)

    outputs = [
      %{
        satoshis: 0,
        locking_script: op_return_script
      }
    ]

    # Add change output
    owner_pubkey = PrivateKey.to_public_key(owner_key)
    owner_pubkey_hash = PublicKey.to_hash(owner_pubkey)

    fee = 50
    change_amount = funding_utxo.satoshis - fee

    outputs = if change_amount > 546 do
      outputs ++ [%{
        satoshis: change_amount,
        locking_script: owner_pubkey_hash
      }]
    else
      outputs
    end

    tx = %Transaction{
      version: 1,
      inputs: [
        %{
          txid: funding_utxo.txid,
          vout: funding_utxo.vout,
          script_sig: "",
          sequence: 0xFFFFFFFF
        }
      ],
      outputs: outputs,
      lock_time: 0
    }

    {:ok, %{tx: tx}}
  end

  @doc """
  Build an INVOCATION transaction with fee
  """
  def build_invocation(ghost_id, params, fee_amount, invoker_key, funding_utxo) do
    payload = %{
      ghost_id: ghost_id,
      params: params,
      nonce: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      ts: System.system_time(:second)
    }

    {:ok, op_return_script} = build_op_return(:invocation, payload)

    invoker_pubkey = PrivateKey.to_public_key(invoker_key)
    invoker_pubkey_hash = PublicKey.to_hash(invoker_pubkey)

    outputs = [
      # Fee output (will be claimed by ghost/executor)
      %{
        satoshis: fee_amount,
        locking_script: invoker_pubkey_hash  # Simplified - actual would use hash puzzle
      },
      # OP_RETURN with invocation data
      %{
        satoshis: 0,
        locking_script: op_return_script
      }
    ]

    # Change
    fee = 150
    change_amount = funding_utxo.satoshis - fee_amount - fee

    outputs = if change_amount > 546 do
      outputs ++ [%{
        satoshis: change_amount,
        locking_script: invoker_pubkey_hash
      }]
    else
      outputs
    end

    tx = %Transaction{
      version: 1,
      inputs: [
        %{
          txid: funding_utxo.txid,
          vout: funding_utxo.vout,
          script_sig: "",
          sequence: 0xFFFFFFFF
        }
      ],
      outputs: outputs,
      lock_time: 0
    }

    {:ok, %{tx: tx, invocation_id: generate_invocation_id(ghost_id, payload)}}
  end

  @doc """
  Build a CHALLENGE transaction
  """
  def build_challenge(ghost_id, challenge_type, evidence, challenger_key, funding_utxo) do
    challenger_stake = 10_000  # 10K sats

    payload = %{
      ghost_id: ghost_id,
      type: challenge_type_code(challenge_type),
      evidence: evidence,
      challenger: challenger_key |> PrivateKey.to_public_key() |> PublicKey.to_binary() |> Base.encode16(case: :lower),
      ts: System.system_time(:second)
    }

    {:ok, op_return_script} = build_op_return(:challenge, payload)

    challenger_pubkey = PrivateKey.to_public_key(challenger_key)
    challenger_pubkey_hash = PublicKey.to_hash(challenger_pubkey)

    outputs = [
      # Challenger stake (locked pending resolution)
      %{
        satoshis: challenger_stake,
        locking_script: challenger_pubkey_hash
      },
      # OP_RETURN
      %{
        satoshis: 0,
        locking_script: op_return_script
      }
    ]

    fee = 100
    change_amount = funding_utxo.satoshis - challenger_stake - fee

    outputs = if change_amount > 546 do
      outputs ++ [%{satoshis: change_amount, locking_script: challenger_pubkey_hash}]
    else
      outputs
    end

    tx = %Transaction{
      version: 1,
      inputs: [
        %{txid: funding_utxo.txid, vout: funding_utxo.vout, script_sig: "", sequence: 0xFFFFFFFF}
      ],
      outputs: outputs,
      lock_time: 0
    }

    {:ok, %{tx: tx}}
  end

  # ----------------------------------------------------------------------------
  # Helper Functions
  # ----------------------------------------------------------------------------

  defp build_op_return(type, payload) do
    type_byte = Map.get(@type_codes, type, 0x00)

    # Encode with MessagePack
    payload_binary = Msgpax.pack!(payload)
    payload_len = byte_size(payload_binary)

    # Build script
    script = <<
      0x6a,                    # OP_RETURN
      0x4d,                    # OP_PUSHDATA2
      (5 + 2 + 1 + 2 + payload_len)::little-16,
      @protocol_prefix,
      @version_0_1_0::binary,
      type_byte,
      payload_len::big-16,
      payload_binary::binary
    >>

    {:ok, script}
  end

  defp ghost_type_code(:greeter), do: 1
  defp ghost_type_code(:oracle), do: 2
  defp ghost_type_code(:guardian), do: 3
  defp ghost_type_code(:merchant), do: 4
  defp ghost_type_code(:custom), do: 5
  defp ghost_type_code(_), do: 0

  defp challenge_type_code(:no_show), do: 1
  defp challenge_type_code(:fraud), do: 2
  defp challenge_type_code(:malfunction), do: 3
  defp challenge_type_code(:timeout), do: 4
  defp challenge_type_code(_), do: 0

  defp lat_lng_to_h3(lat, lng) do
    # Placeholder - actual H3 encoding would use h3 library
    # For now, return a hash of the coordinates
    data = "#{lat}:#{lng}"
    :crypto.hash(:sha256, data) |> :binary.part(0, 8) |> :binary.decode_unsigned()
  end

  defp generate_invocation_id(ghost_id, payload) do
    data = ghost_id << Jason.encode!(payload)
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end
end
