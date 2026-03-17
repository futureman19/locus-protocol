defmodule Locus do
  @moduledoc """
  Locus Protocol Reference Node

  A permissionless system for deploying location-aware autonomous agents ("ghosts")
  on the Bitcoin SV blockchain.

  ## Architecture

  - No database - all state derived from blockchain
  - gRPC for local API (no REST server)
  - CLTV-based staking for economic security
  - Overlay network for ghost discovery

  ## Phase 2 Implementation

  This reference implementation includes:

  - **Locus.Chain**: BSV blockchain interaction via bsv_sdk
  - **Locus.TxBuilder**: Transaction construction for all protocol types
  - **Locus.State**: Protocol state machine
  - **Locus.Ghost**: Ghost lifecycle management
  - **Locus.Staking**: CLTV staking and slashing
  - **Locus.Heartbeat**: Proof-of-liveness protocol
  - **Locus.Invocation**: Fee processing and distribution
  - **Locus.Challenge**: Dispute resolution
  - **Locus.Registry**: In-memory state index

  ## Usage

  Start the node:

      iex -S mix

  Build a ghost registration transaction:

      alias Locus.TxBuilder
      {:ok, %{tx: tx}} = TxBuilder.build_ghost_register(
        owner_key,
        [
          name: "My Oracle",
          type: :oracle,
          lat: 40.7128,
          lng: -74.0060,
          stake_amount: 10_000_000,
          code_hash: "abc123..."
        ],
        funding_utxo,
        current_height
      )

  """

  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Locus Protocol Reference Node v0.1.0")

    genesis_path = Application.get_env(:locus, :genesis_config_path, "")
    metrics_output_path = Application.get_env(:locus, :metrics_output_path, "")

    base_children = [
      # State management
      Locus.State,
      Locus.Registry,

      # Protocol modules
      Locus.Ghost,
      Locus.Staking,
      Locus.Heartbeat,
      Locus.Invocation,
      Locus.Challenge,

      # Blockchain interface
      {Locus.Chain, [
        network: Application.get_env(:locus, :network, :testnet),
        arc_endpoint: Application.get_env(:locus, :arc_endpoint),
        arc_api_key: Application.get_env(:locus, :arc_api_key, "")
      ]}
    ]

    reporter_children =
      case metrics_output_path do
        "" -> []
        path -> [{Locus.RuntimeReporter, [output_path: path]}]
      end

    case genesis_path do
      "" ->
        Logger.warning("No LOCUS_GENESIS_CONFIG configured for this node")

      path ->
        case Locus.Genesis.load(path) do
          {:ok, genesis} ->
            Logger.info(
              "Loaded genesis config #{path} with #{length(genesis["cities"])} cities and #{length(genesis["nodes"])} nodes"
            )

          {:error, reason} ->
            Logger.warning("Failed to load genesis config #{path}: #{inspect(reason)}")
        end
    end

    Supervisor.init(base_children ++ reporter_children, strategy: :one_for_one)
  end

  @doc """
  Get node status
  """
  def status do
    genesis_path = Application.get_env(:locus, :genesis_config_path, "")

    %{
      version: "0.1.0",
      phase: "Phase 2 - Reference Node",
      node_name: Application.get_env(:locus, :node_name, "locus-testnet-node"),
      network: Application.get_env(:locus, :network, :testnet),
      genesis: Locus.Genesis.summary(genesis_path),
      modules: [
        Locus.Chain,
        Locus.TxBuilder,
        Locus.State,
        Locus.Ghost,
        Locus.Staking,
        Locus.Heartbeat,
        Locus.Invocation,
        Locus.Challenge,
        Locus.Registry
      ]
    }
  end
end
