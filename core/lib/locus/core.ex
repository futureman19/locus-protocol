defmodule Locus.Core do
  @moduledoc """
  Locus Protocol — Core Territory Layer

  Territory-centric protocol for location-aware digital cities on Bitcoin SV.
  Cities are the primary primitive. All state derives from chain.

  ## Architecture

  - **Locus.City** — Found cities, lifecycle phases, citizen management
  - **Locus.Territory** — Claim/release/transfer at all hierarchy levels
  - **Locus.Fibonacci** — Block unlock calculations for city phases
  - **Locus.Treasury** — BSV tracking, UBI distribution, token redemption
  - **Locus.Governance** — Proposals, voting, execution (Genesis/Federal)
  - **Locus.Staking** — CLTV lock scripts, emergency unlock
  - **Locus.Transaction** — OP_RETURN encoding (MessagePack)
  - **Locus.Chain** — ARC broadcasting, blockchain interaction
  """

  use Supervisor

  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Locus Protocol Core Territory Layer v0.1.0")

    children = [
      # Blockchain interface
      {Locus.Chain, [
        network: Application.get_env(:locus_core, :network, :testnet),
        arc_endpoint: Application.get_env(:locus_core, :arc_endpoint),
        arc_api_key: Application.get_env(:locus_core, :arc_api_key, "")
      ]},

      # Core state processes
      Locus.Treasury,
      Locus.Staking,
      Locus.Governance
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def version, do: "0.1.0"
end
