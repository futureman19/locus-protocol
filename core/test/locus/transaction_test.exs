defmodule Locus.TransactionTest do
  use ExUnit.Case, async: true

  alias Locus.Transaction

  describe "encode/2 and decode/1" do
    test "round-trips a city_found transaction" do
      payload = %{"name" => "Genesis", "stake" => 1_000_000}

      {:ok, script} = Transaction.encode(:city_found, payload)
      assert is_binary(script)

      # Script starts with OP_RETURN
      assert <<0x6a, _::binary>> = script

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :city_found
      assert decoded.version == "0.1"
      assert decoded.data["name"] == "Genesis"
      assert decoded.data["stake"] == 1_000_000
    end

    test "round-trips a territory_claim transaction" do
      payload = %{"territory" => "deadbeef", "city" => "cafebabe"}

      {:ok, script} = Transaction.encode(:territory_claim, payload)
      {:ok, decoded} = Transaction.decode(script)

      assert decoded.type == :territory_claim
      assert decoded.data["territory"] == "deadbeef"
    end

    test "rejects unknown type" do
      assert {:error, :unknown_type} = Transaction.encode(:bogus, %{})
    end
  end

  describe "type_codes/0" do
    test "has 14 territory protocol types" do
      codes = Transaction.type_codes()
      assert map_size(codes) == 14
      assert Map.has_key?(codes, :city_found)
      assert Map.has_key?(codes, :territory_claim)
      assert Map.has_key?(codes, :ubi_claim)
      assert Map.has_key?(codes, :lock_to_mint)
    end

    test "all type codes are in 0x10-0x1F range" do
      Transaction.type_codes()
      |> Map.values()
      |> Enum.each(fn code ->
        assert code >= 0x10 and code <= 0x1F
      end)
    end
  end

  describe "payload builders" do
    test "build_city_found/4 creates valid script" do
      {:ok, script} = Transaction.build_city_found(
        "TestCity", <<1::128>>, "founder_key", 1_000_000,
        timestamp: 1_700_000_000
      )

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.data["name"] == "TestCity"
      assert decoded.data["stake"] == 1_000_000
    end

    test "build_stake_lock/4 creates valid script" do
      {:ok, script} = Transaction.build_stake_lock(
        "city_id", "staker_key", 500_000, 821_600
      )

      {:ok, decoded} = Transaction.decode(script)
      assert decoded.type == :stake_lock
      assert decoded.data["amount"] == 500_000
      assert decoded.data["lock_h"] == 821_600
    end
  end
end
