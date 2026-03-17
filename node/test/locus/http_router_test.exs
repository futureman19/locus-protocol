defmodule Locus.HttpRouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  test "health endpoint returns node metadata" do
    conn =
      :get
      |> conn("/health")
      |> Locus.HttpRouter.call([])

    assert conn.status == 200
    assert %{"status" => "ok", "service" => "locus-node"} = Jason.decode!(conn.resp_body)
  end

  test "status endpoint returns protocol status payload" do
    conn =
      :get
      |> conn("/status")
      |> Locus.HttpRouter.call([])

    assert conn.status == 200

    assert %{"phase" => "Phase 2 - Reference Node", "version" => "0.1.0"} =
             Jason.decode!(conn.resp_body)
  end
end
