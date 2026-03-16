defmodule Locus.TransactionTest do
  use ExUnit.Case, async: true

  alias Locus.Transaction

  describe "encode/2 and decode/1" do
    test "round-trips a city_found message" do
      payload = %{"name" => "Neo-Tokyo", "stake" => 3_200_000_000}

      {:ok, script} = Transaction.encode(:city_found, payload)
      assert is_binary(script)
      assert <<0x6a, _::binary>> = script  # Starts with OP_RETURN

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :city_found
      assert decoded.version == 1
      assert decoded.data["name"] == "Neo-Tokyo"
      assert decoded.data["stake"] == 3_200_000_000
    end

    test "round-trips a territory_claim message" do
      payload = %{"level" => 8, "location" => "891f1d48177ffff"}

      {:ok, script} = Transaction.encode(:territory_claim, payload)
      {:ok, decoded} = Transaction.decode(script)

      assert decoded.type == :territory_claim
      assert decoded.data["level"] == 8
    end

    test "round-trips a gov_vote message" do
      payload = %{"proposal_id" => "abc123", "vote" => 1}

      {:ok, script} = Transaction.encode(:gov_vote, payload)
      {:ok, decoded} = Transaction.decode(script)

      assert decoded.type == :gov_vote
      assert decoded.data["vote"] == 1
    end

    test "round-trips a ubi_claim message" do
      payload = %{"city_id" => "city1", "claim_periods" => 7}

      {:ok, script} = Transaction.encode(:ubi_claim, payload)
      {:ok, decoded} = Transaction.decode(script)

      assert decoded.type == :ubi_claim
      assert decoded.data["claim_periods"] == 7
    end

    test "rejects unknown type" do
      assert {:error, :unknown_type} = Transaction.encode(:bogus, %{})
    end

    test "decode rejects non-LOCUS data" do
      assert {:error, :invalid_script} = Transaction.decode(<<0x00, 0x01, 0x02>>)
    end
  end

  describe "type_codes/0" do
    test "has all 17 territory protocol types" do
      codes = Transaction.type_codes()
      assert map_size(codes) == 17

      # City operations
      assert Map.has_key?(codes, :city_found)
      assert Map.has_key?(codes, :citizen_join)

      # Territory operations
      assert Map.has_key?(codes, :territory_claim)
      assert Map.has_key?(codes, :territory_transfer)

      # Governance
      assert Map.has_key?(codes, :gov_propose)
      assert Map.has_key?(codes, :gov_vote)

      # UBI
      assert Map.has_key?(codes, :ubi_claim)

      # Objects and ghosts
      assert Map.has_key?(codes, :object_deploy)
      assert Map.has_key?(codes, :ghost_invoke)

      # Heartbeat
      assert Map.has_key?(codes, :heartbeat)
    end

    test "type codes match spec 07" do
      codes = Transaction.type_codes()
      assert codes[:city_found] == 0x01
      assert codes[:citizen_join] == 0x03
      assert codes[:territory_claim] == 0x10
      assert codes[:object_deploy] == 0x20
      assert codes[:heartbeat] == 0x30
      assert codes[:ghost_invoke] == 0x40
      assert codes[:gov_propose] == 0x50
      assert codes[:ubi_claim] == 0x60
    end
  end

  describe "payload builders" do
    test "build_city_found/1" do
      {:ok, script} = Transaction.build_city_found(%{
        name: "TestCity",
        description: "A test city",
        lat: 35.6762,
        lng: 139.6503,
        h3_res7: "8f283080dcb019d",
        founder_pubkey: "pubkey_data",
        policies: %{"immigration" => "open"}
      })

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.data["name"] == "TestCity"
      assert decoded.data["location"]["h3_res7"] == "8f283080dcb019d"
    end

    test "build_territory_claim/1" do
      {:ok, script} = Transaction.build_territory_claim(%{
        level: 8,
        h3_index: "891f1d48177ffff",
        owner_pubkey: "owner_key",
        stake_amount: 800_000_000,
        lock_height: 821_600
      })

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :territory_claim
      assert decoded.data["stake_amount"] == 800_000_000
    end

    test "build_gov_vote/3" do
      {:ok, script} = Transaction.build_gov_vote("proposal_id", "voter_key", :yes)

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :gov_vote
      assert decoded.data["vote"] == 1
    end

    test "build_ubi_claim/3" do
      {:ok, script} = Transaction.build_ubi_claim("city_id", "citizen_key", 7)

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :ubi_claim
      assert decoded.data["claim_periods"] == 7
    end
  end
end
