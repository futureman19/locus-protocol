defmodule Locus.HttpServer do
  @moduledoc false

  def child_spec(opts) do
    host = Keyword.get(opts, :host, "0.0.0.0")
    port = Keyword.fetch!(opts, :port)

    Supervisor.child_spec(
      {Plug.Cowboy,
       scheme: :http,
       plug: Locus.HttpRouter,
       options: [ip: parse_host(host), port: port]},
      id: __MODULE__
    )
  end

  defp parse_host(host) when is_binary(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} -> address
      {:error, _reason} -> {0, 0, 0, 0}
    end
  end
end
