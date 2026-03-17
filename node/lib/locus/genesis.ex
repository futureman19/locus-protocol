defmodule Locus.Genesis do
  @moduledoc """
  Genesis configuration loader and validator for local testnet nodes.
  """

  @required_top_level ~w(network chain nodes cities)
  @required_chain ~w(protocol network start_height)
  @required_node ~w(name role host distribution_name)
  @required_city ~w(slug name phase citizen_count blocks_unlocked treasury_bsv founder_pubkey location)

  @spec load(String.t()) :: {:ok, map()} | {:error, term()}
  def load(path) when is_binary(path) and path != "" do
    with {:ok, contents} <- File.read(path),
         {:ok, decoded} <- Jason.decode(contents),
         :ok <- validate(decoded) do
      {:ok, decoded}
    end
  end

  def load(_path), do: {:error, :missing_genesis_path}

  @spec validate(map()) :: :ok | {:error, term()}
  def validate(genesis) when is_map(genesis) do
    with :ok <- require_keys(genesis, @required_top_level, :top_level),
         :ok <- require_keys(genesis["chain"], @required_chain, :chain),
         :ok <- validate_nodes(genesis["nodes"]),
         :ok <- validate_cities(genesis["cities"]) do
      :ok
    end
  end

  def validate(_), do: {:error, :invalid_genesis_document}

  @spec summary(String.t()) :: map()
  def summary(path) do
    case load(path) do
      {:ok, genesis} ->
        %{
          loaded: true,
          network: genesis["network"],
          start_height: get_in(genesis, ["chain", "start_height"]),
          node_count: length(genesis["nodes"] || []),
          city_count: length(genesis["cities"] || [])
        }

      {:error, reason} ->
        %{
          loaded: false,
          error: inspect(reason)
        }
    end
  end

  defp validate_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {node, index}, _acc ->
      case require_keys(node, @required_node, {:node, index}) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_nodes(_), do: {:error, :invalid_nodes}

  defp validate_cities(cities) when is_list(cities) do
    cities
    |> Enum.with_index(1)
    |> Enum.reduce_while(:ok, fn {city, index}, _acc ->
      case require_keys(city, @required_city, {:city, index}) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_cities(_), do: {:error, :invalid_cities}

  defp require_keys(map, keys, scope) when is_map(map) do
    missing = Enum.reject(keys, &Map.has_key?(map, &1))

    if missing == [] do
      :ok
    else
      {:error, {:missing_keys, scope, missing}}
    end
  end

  defp require_keys(_value, _keys, scope), do: {:error, {:invalid_scope, scope}}
end
