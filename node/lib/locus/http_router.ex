defmodule Locus.HttpRouter do
  @moduledoc false

  use Plug.Router

  plug :match
  plug :dispatch

  get "/health" do
    payload = %{
      status: "ok",
      service: "locus-node",
      node_name: Application.get_env(:locus, :node_name, "locus-node"),
      network: Application.get_env(:locus, :network, :testnet)
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(payload))
  end

  get "/status" do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(Locus.status()))
  end

  match _ do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(404, Jason.encode!(%{error: "not_found"}))
  end
end
