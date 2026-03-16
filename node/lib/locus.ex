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
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Locus.Registry,
      Locus.Chain,
      Locus.Ghost,
      Locus.Staking,
      Locus.Heartbeat,
      Locus.Invocation,
      Locus.Challenge
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
