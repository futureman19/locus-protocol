defmodule Locus.Registry do
  @moduledoc """
  In-memory ghost registry

  Maintains current state of all ghosts derived from blockchain.
  """

  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{ghosts: %{}, by_location: %{}}}
  end

  @doc """
  Register a ghost
  """
  def register_ghost(ghost) do
    GenServer.call(__MODULE__, {:register, ghost})
  end

  @doc """
  Get ghost by ID
  """
  def get_ghost(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  @doc """
  List ghosts by H3 index
  """
  def list_by_location(h3_index) do
    GenServer.call(__MODULE__, {:list_by_location, h3_index})
  end

  @impl true
  def handle_call({:register, ghost}, _from, state) do
    new_ghosts = Map.put(state.ghosts, ghost.id, ghost)

    # Index by H3 location
    location_ghosts = Map.get(state.by_location, ghost.h3_index, [])
    new_by_location = Map.put(state.by_location, ghost.h3_index, [ghost.id | location_ghosts])

    {:reply, :ok, %{state | ghosts: new_ghosts, by_location: new_by_location}}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    {:reply, Map.get(state.ghosts, id), state}
  end

  @impl true
  def handle_call({:list_by_location, h3_index}, _from, state) do
    ghost_ids = Map.get(state.by_location, h3_index, [])
    ghosts = Enum.map(ghost_ids, &Map.get(state.ghosts, &1))
    {:reply, ghosts, state}
  end
end
