defmodule Locus.GenesisTest do
  use ExUnit.Case, async: true

  alias Locus.Genesis

  test "validates a complete genesis document" do
    genesis = %{
      "network" => "testnet",
      "chain" => %{
        "protocol" => "locus",
        "network" => "testnet",
        "start_height" => 910_000
      },
      "nodes" => [
        %{
          "name" => "seed-a",
          "role" => "seed",
          "host" => "127.0.0.1",
          "distribution_name" => "seed_a"
        }
      ],
      "cities" => [
        %{
          "slug" => "atlas",
          "name" => "Atlas Prime",
          "phase" => "genesis",
          "citizen_count" => 1,
          "blocks_unlocked" => 2,
          "treasury_bsv" => 3_200_000_000,
          "founder_pubkey" => "02atlas",
          "location" => %{"lat" => 37.7749, "lng" => -122.4194}
        }
      ]
    }

    assert :ok = Genesis.validate(genesis)
  end

  test "loads and summarizes a persisted genesis file" do
    path =
      Path.join(
        System.tmp_dir!(),
        "locus-genesis-test-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(path) end)

    payload = %{
      "network" => "testnet",
      "chain" => %{
        "protocol" => "locus",
        "network" => "testnet",
        "start_height" => 910_000
      },
      "nodes" => [
        %{
          "name" => "seed-a",
          "role" => "seed",
          "host" => "127.0.0.1",
          "distribution_name" => "seed_a"
        },
        %{
          "name" => "validator-b",
          "role" => "validator",
          "host" => "127.0.0.1",
          "distribution_name" => "validator_b"
        }
      ],
      "cities" => [
        %{
          "slug" => "atlas",
          "name" => "Atlas Prime",
          "phase" => "genesis",
          "citizen_count" => 1,
          "blocks_unlocked" => 2,
          "treasury_bsv" => 3_200_000_000,
          "founder_pubkey" => "02atlas",
          "location" => %{"lat" => 37.7749, "lng" => -122.4194}
        }
      ]
    }

    File.write!(path, Jason.encode!(payload))

    assert {:ok, loaded} = Genesis.load(path)
    assert loaded["network"] == "testnet"

    assert %{
             loaded: true,
             network: "testnet",
             start_height: 910_000,
             node_count: 2,
             city_count: 1
           } = Genesis.summary(path)
  end
end
