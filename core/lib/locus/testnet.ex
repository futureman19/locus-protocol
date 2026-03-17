defmodule Locus.Testnet do
  @moduledoc """
  Fixture-driven local testnet orchestration for deployment automation.

  This module turns the JSON fixtures under `testnet/fixtures` into:

  - a deterministic genesis configuration for testnet nodes
  - a reproducible city lifecycle scenario
  - validation reports for phases, Fibonacci unlocks, funding, and UBI math
  """

  alias Locus.{City, Fibonacci, Treasury}

  @default_start_height 910_000
  @join_height_step 12
  @sats_per_bsv 100_000_000

  @type fixture_bundle :: %{
          keys: map(),
          cities: map(),
          transactions: map(),
          topology: map()
        }

  @type scenario :: map()

  @doc "Default fixture directory for the repository."
  @spec default_fixtures_dir() :: String.t()
  def default_fixtures_dir do
    Path.expand(Path.join(__DIR__, "../../../testnet/fixtures"))
  end

  @doc "Load the testnet fixtures from disk."
  @spec load_fixtures!(String.t()) :: fixture_bundle()
  def load_fixtures!(fixtures_dir \\ default_fixtures_dir()) do
    %{
      keys: load_json!(Path.join(fixtures_dir, "mock_keys.json")),
      cities: load_json!(Path.join(fixtures_dir, "cities.json")),
      transactions: load_json!(Path.join(fixtures_dir, "transactions.json")),
      topology: load_json!(Path.join(fixtures_dir, "topology.json"))
    }
  end

  @doc "Build a full scenario from the fixture bundle."
  @spec build_scenario!(keyword()) :: scenario()
  def build_scenario!(opts \\ []) do
    fixtures_dir = Keyword.get(opts, :fixtures_dir, default_fixtures_dir())
    fixtures = load_fixtures!(fixtures_dir)
    start_height = opts[:start_height] || fixture_start_height(fixtures)
    generated_at = DateTime.utc_now() |> DateTime.to_iso8601()

    key_index = build_key_index(fixtures.keys)
    available_citizens = Enum.map(fixtures.keys["citizens"] || [], & &1["id"])
    node_list = normalize_nodes(fixtures.topology["nodes"] || [], fixtures.topology)

    {cities, available_citizens} =
      Enum.reduce(fixtures.cities["cities"], {%{}, available_citizens}, fn city_fixture,
                                                                          {city_acc, pool_acc} ->
        {city_record, remaining_pool} =
          build_initial_city!(city_fixture, key_index, pool_acc, start_height)

        {Map.put(city_acc, city_record.slug, city_record), remaining_pool}
      end)

    {cities, join_plan_results, _remaining_citizens} =
      cities
      |> apply_funding_events(fixtures.transactions["funding"] || [])
      |> apply_join_plans(
        fixtures.transactions["join_plans"] || [],
        key_index,
        available_citizens,
        start_height
      )

    cities =
      apply_ubi_rounds(cities, fixtures.transactions["ubi_rounds"] || [])

    city_summaries =
      cities
      |> Map.values()
      |> Enum.sort_by(& &1.slug)
      |> Enum.map(&finalize_city_record/1)

    scenario = %{
      generated_at: generated_at,
      network: fixtures.topology["network"] || fixtures.cities["network"] || "testnet",
      cluster: fixtures.topology["cluster"] || "locus-local-testnet",
      start_height: start_height,
      nodes: node_list,
      cities: city_summaries,
      join_plan_results: join_plan_results
    }

    Map.put(scenario, :validation, validate_scenario(scenario))
  end

  @doc "Render the node-facing genesis configuration for the initial city state."
  @spec render_genesis_config(scenario()) :: map()
  def render_genesis_config(%{} = scenario) do
    %{
      network: scenario.network,
      cluster: scenario.cluster,
      generated_at: scenario.generated_at,
      chain: %{
        protocol: "locus",
        network: scenario.network,
        start_height: scenario.start_height
      },
      nodes:
        Enum.map(scenario.nodes, fn node ->
          Map.take(node, [:name, :role, :host, :distribution_name, :rpc_port, :metrics_port])
        end),
      cities:
        Enum.map(scenario.cities, fn city ->
          %{
            slug: city.slug,
            name: city.name,
            city_id: city.initial_state.city_id,
            territory_id: city.initial_state.territory_id,
            founder_pubkey: city.founder_pubkey,
            phase: city.initial_state.phase,
            citizen_count: city.initial_state.citizen_count,
            blocks_unlocked: city.initial_state.blocks_unlocked,
            treasury_bsv: city.initial_state.treasury_bsv,
            treasury_bsv_display: city.initial_state.treasury_bsv_display,
            location: city.location,
            policies: city.policies
          }
        end),
      automation: %{
        join_plans: scenario.join_plan_results,
        validation_summary: scenario.validation.summary
      }
    }
  end

  @doc "Persist a JSON document to disk."
  @spec write_json!(String.t(), map()) :: :ok
  def write_json!(path, payload) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, Jason.encode_to_iodata!(payload, pretty: true))
  end

  @doc "Build a validation report for a testnet scenario."
  @spec validate_scenario(scenario()) :: map()
  def validate_scenario(%{} = scenario) do
    node_checks = [
      build_check(
        "node-count",
        length(scenario.nodes) > 0,
        %{expected: :positive, actual: length(scenario.nodes)}
      ),
      build_check(
        "unique-node-names",
        unique_values?(Enum.map(scenario.nodes, & &1.name)),
        %{names: Enum.map(scenario.nodes, & &1.name)}
      )
    ]

    city_checks =
      Enum.flat_map(scenario.cities, fn city ->
        [
          build_check(
            "#{city.slug}:initial-phase",
            city.initial_state.phase == city.initial_expectations.phase,
            %{
              expected: city.initial_expectations.phase,
              actual: city.initial_state.phase
            }
          ),
          build_check(
            "#{city.slug}:initial-blocks",
            city.initial_state.blocks_unlocked == city.initial_expectations.blocks_unlocked,
            %{
              expected: city.initial_expectations.blocks_unlocked,
              actual: city.initial_state.blocks_unlocked
            }
          )
        ] ++ Enum.map(city.ubi_events, &validate_ubi_event(city.slug, &1))
      end)

    join_checks =
      Enum.map(scenario.join_plan_results, fn result ->
        build_check(
          "#{result.id}:join-plan",
          result.passed,
          %{
            city_slug: result.city_slug,
            expected_phase: result.expected_phase,
            actual_phase: result.actual_phase,
            expected_blocks_unlocked: result.expected_blocks_unlocked,
            actual_blocks_unlocked: result.actual_blocks_unlocked
          }
        )
      end)

    checks = node_checks ++ city_checks ++ join_checks

    %{
      passed: Enum.all?(checks, & &1.passed),
      checks: checks,
      summary: %{
        nodes: length(scenario.nodes),
        cities: length(scenario.cities),
        join_plans: length(scenario.join_plan_results),
        ubi_rounds:
          scenario.cities
          |> Enum.map(fn city -> length(city.ubi_events) end)
          |> Enum.sum()
      }
    }
  end

  defp build_initial_city!(city_fixture, key_index, available_citizens, start_height) do
    founder = fetch_key!(key_index, city_fixture["founder_id"])
    target_citizens = city_fixture["target_citizens"] || 1
    resident_count = max(target_citizens - 1, 0)

    {resident_ids, remaining_citizens} =
      resolve_joiner_ids(
        city_fixture["resident_ids"],
        resident_count,
        available_citizens,
        "initial residents for #{city_fixture["slug"]}"
      )

    found_opts = [
      description: city_fixture["description"] || "",
      policies: city_fixture["policies"] || %{},
      stake_amount: city_fixture["stake_amount_sats"] || 3_200_000_000,
      stake_txid: city_fixture["stake_txid"] || "#{city_fixture["slug"]}-founding-tx"
    ]

    {:ok, city, founder_citizen} =
      City.found(
        city_fixture["name"],
        city_fixture["location"] || %{},
        founder["pubkey"],
        start_height,
        found_opts
      )

    {city, citizen_records, join_events} =
      resident_ids
      |> Enum.with_index(1)
      |> Enum.reduce({city, [summarize_key(founder)], []}, fn {resident_id, offset},
                                                             {city_acc, citizens_acc, join_acc} ->
        joiner = fetch_key!(key_index, resident_id)
        join_height = start_height + offset

        {:ok, updated_city, _citizen} =
          City.add_citizen(city_acc, joiner["pubkey"], join_height,
            stake_amount: city_fixture["citizen_stake_sats"] || 0,
            stake_txid: "#{city_fixture["slug"]}-resident-#{resident_id}-tx"
          )

        join_event = %{
          source: "initial_population",
          joiner_id: resident_id,
          pubkey: joiner["pubkey"],
          height: join_height,
          citizen_count: updated_city.citizen_count,
          phase: Atom.to_string(updated_city.phase),
          blocks_unlocked: updated_city.blocks_unlocked
        }

        {updated_city, citizens_acc ++ [summarize_key(joiner)], join_acc ++ [join_event]}
      end)

    city =
      apply_city_funding(
        city,
        city_fixture["initial_treasury_funding_sats"] || 0
      )

    initial_state = summarize_city(city)

    record = %{
      slug: city_fixture["slug"],
      name: city_fixture["name"],
      description: city_fixture["description"] || "",
      founder_key: summarize_key(founder),
      founder_citizen: %{
        pubkey: founder_citizen.pubkey,
        joined_at: founder_citizen.joined_at,
        lock_height: founder_citizen.lock_height
      },
      fixture: city_fixture,
      city: city,
      citizens: citizen_records,
      funding_events: initial_funding_events(city_fixture, city.treasury_bsv),
      join_events: join_events,
      ubi_events: [],
      checkpoints: [
        Map.put(initial_state, :label, "initial")
      ],
      initial_state: initial_state,
      initial_expectations: %{
        phase:
          city_fixture["expected_phase"] ||
            city_fixture
            |> Map.get("target_citizens", 1)
            |> Fibonacci.phase_for_citizens()
            |> Atom.to_string(),
        blocks_unlocked:
          city_fixture["expected_blocks_unlocked"] ||
            Fibonacci.blocks_for_citizens(target_citizens),
        citizen_count: target_citizens
      }
    }

    {record, remaining_citizens}
  end

  defp apply_funding_events(city_map, funding_events) do
    Enum.reduce(funding_events, city_map, fn event, acc ->
      slug = event["city_slug"]
      record = Map.fetch!(acc, slug)
      amount_sats = event["amount_sats"] || 0
      updated_city = apply_city_funding(record.city, amount_sats)

      funding_event = %{
        txid: event["txid"] || "#{slug}-funding-#{length(record.funding_events) + 1}",
        reason: event["reason"] || "treasury-bootstrap",
        amount_sats: amount_sats,
        amount_bsv_display: sats_to_bsv(amount_sats),
        treasury_after_sats: updated_city.treasury_bsv,
        treasury_after_bsv_display: sats_to_bsv(updated_city.treasury_bsv)
      }

      updated_record = %{
        record
        | city: updated_city,
          funding_events: record.funding_events ++ [funding_event]
      }

      Map.put(acc, slug, updated_record)
    end)
  end

  defp apply_join_plans(city_map, join_plans, key_index, available_citizens, start_height) do
    Enum.with_index(join_plans, 1)
    |> Enum.reduce({city_map, [], available_citizens}, fn {plan, plan_index},
                                                          {acc, results, pool_acc} ->
      slug = plan["city_slug"]
      record = Map.fetch!(acc, slug)
      requested_joiners = plan["joiner_count"] || length(plan["joiner_ids"] || [])

      {joiner_ids, remaining_citizens} =
        resolve_joiner_ids(
          plan["joiner_ids"],
          requested_joiners,
          pool_acc,
          "join plan #{plan["id"] || plan_index}"
        )

      {updated_record, _final_height} =
        joiner_ids
        |> Enum.with_index(1)
        |> Enum.reduce({record, start_height + plan_index * 100}, fn {joiner_id, join_index},
                                                                     {record_acc, height_seed} ->
          joiner = fetch_key!(key_index, joiner_id)
          join_height = height_seed + join_index * @join_height_step

          {:ok, updated_city, _citizen} =
            City.add_citizen(record_acc.city, joiner["pubkey"], join_height,
              stake_amount: plan["stake_amount_sats"] || 0,
              stake_txid: "#{slug}-join-#{joiner_id}-tx"
            )

          join_event = %{
            source: plan["id"] || "join-plan-#{plan_index}",
            joiner_id: joiner_id,
            pubkey: joiner["pubkey"],
            height: join_height,
            citizen_count: updated_city.citizen_count,
            phase: Atom.to_string(updated_city.phase),
            blocks_unlocked: updated_city.blocks_unlocked
          }

          updated_record = %{
            record_acc
            | city: updated_city,
              citizens: record_acc.citizens ++ [summarize_key(joiner)],
              join_events: record_acc.join_events ++ [join_event]
          }

          {updated_record, join_height}
        end)

      checkpoint =
        updated_record.city
        |> summarize_city()
        |> Map.put(:label, plan["id"] || "join-plan-#{plan_index}")

      expected_phase =
        plan["expected_phase"] ||
          updated_record.city.citizen_count
          |> Fibonacci.phase_for_citizens()
          |> Atom.to_string()

      expected_blocks =
        plan["expected_blocks_unlocked"] ||
          Fibonacci.blocks_for_citizens(updated_record.city.citizen_count)

      updated_record = %{
        updated_record
        | checkpoints: updated_record.checkpoints ++ [checkpoint]
      }

      result = %{
        id: plan["id"] || "join-plan-#{plan_index}",
        city_slug: slug,
        join_count: length(joiner_ids),
        expected_phase: expected_phase,
        actual_phase: Atom.to_string(updated_record.city.phase),
        expected_blocks_unlocked: expected_blocks,
        actual_blocks_unlocked: updated_record.city.blocks_unlocked,
        passed:
          expected_phase == Atom.to_string(updated_record.city.phase) and
            expected_blocks == updated_record.city.blocks_unlocked
      }

      {Map.put(acc, slug, updated_record), results ++ [result], remaining_citizens}
    end)
  end

  defp apply_ubi_rounds(city_map, ubi_rounds) do
    Enum.reduce(ubi_rounds, city_map, fn ubi_round, acc ->
      slug = ubi_round["city_slug"]
      rounds = ubi_round["rounds"] || 1
      record = Map.fetch!(acc, slug)

      updated_record =
        Enum.reduce(1..rounds, record, fn round_number, record_acc ->
          city_before = record_acc.city
          {:ok, per_citizen} = Treasury.calculate_city_ubi(city_before)
          {:ok, _distributions, city_after} = Treasury.distribute_ubi(city_before)
          total_sats = per_citizen * city_before.citizen_count

          event = %{
            city_slug: slug,
            round: round_number,
            citizen_count_before: city_before.citizen_count,
            per_citizen_sats: per_citizen,
            per_citizen_bsv_display: sats_to_bsv(per_citizen),
            total_sats: total_sats,
            total_bsv_display: sats_to_bsv(total_sats),
            treasury_before_sats: city_before.treasury_bsv,
            treasury_after_sats: city_after.treasury_bsv
          }

          %{record_acc | city: city_after, ubi_events: record_acc.ubi_events ++ [event]}
        end)

      Map.put(acc, slug, updated_record)
    end)
  end

  defp finalize_city_record(record) do
    %{
      slug: record.slug,
      name: record.name,
      description: record.description,
      founder_pubkey: record.founder_key.pubkey,
      founder_id: record.founder_key.id,
      location: record.fixture["location"] || %{},
      policies: record.fixture["policies"] || %{},
      initial_expectations: record.initial_expectations,
      initial_state: record.initial_state,
      final_state: summarize_city(record.city),
      checkpoints: record.checkpoints,
      citizens: record.citizens,
      funding_events: record.funding_events,
      join_events: record.join_events,
      ubi_events: record.ubi_events
    }
  end

  defp validate_ubi_event(slug, event) do
    build_check(
      "#{slug}:ubi-round-#{event.round}",
      event.total_sats == event.per_citizen_sats * event.citizen_count_before and
        event.treasury_after_sats == event.treasury_before_sats - event.total_sats,
      %{
        total_sats: event.total_sats,
        per_citizen_sats: event.per_citizen_sats,
        citizen_count_before: event.citizen_count_before,
        treasury_before_sats: event.treasury_before_sats,
        treasury_after_sats: event.treasury_after_sats
      }
    )
  end

  defp build_key_index(keys_fixture) do
    (keys_fixture["founders"] || [])
    |> Kernel.++(keys_fixture["citizens"] || [])
    |> Enum.into(%{}, fn key -> {key["id"], key} end)
  end

  defp resolve_joiner_ids(explicit_ids, requested_count, available_citizens, scope)

  defp resolve_joiner_ids(nil, requested_count, available_citizens, scope) do
    take_from_pool(available_citizens, requested_count, scope)
  end

  defp resolve_joiner_ids(explicit_ids, requested_count, available_citizens, scope)
       when is_list(explicit_ids) do
    if length(explicit_ids) != requested_count do
      raise ArgumentError,
            "#{scope} expected #{requested_count} ids but received #{length(explicit_ids)}"
    end

    missing_ids = Enum.reject(explicit_ids, &(&1 in available_citizens))

    if missing_ids != [] do
      raise ArgumentError,
            "#{scope} references unavailable citizen ids: #{Enum.join(missing_ids, ", ")}"
    end

    remaining_citizens = available_citizens -- explicit_ids
    {explicit_ids, remaining_citizens}
  end

  defp take_from_pool(available_citizens, requested_count, scope) do
    if requested_count > length(available_citizens) do
      raise ArgumentError,
            "#{scope} requested #{requested_count} citizens but only #{length(available_citizens)} remain"
    end

    joiner_ids = Enum.take(available_citizens, requested_count)
    remaining_citizens = Enum.drop(available_citizens, requested_count)
    {joiner_ids, remaining_citizens}
  end

  defp normalize_nodes(nodes, topology) do
    Enum.map(nodes, fn node ->
      %{
        name: node["name"],
        role: node["role"] || "validator",
        host: node["host"] || "127.0.0.1",
        distribution_name: node["distribution_name"] || node["name"],
        rpc_port: node["rpc_port"] || 0,
        metrics_port: node["metrics_port"] || 0,
        arc_endpoint: node["arc_endpoint"] || topology["arc_endpoint"] || "https://arc.gorillapool.io"
      }
    end)
  end

  defp fetch_key!(key_index, key_id) do
    case Map.fetch(key_index, key_id) do
      {:ok, key} -> key
      :error -> raise ArgumentError, "unknown key fixture id #{inspect(key_id)}"
    end
  end

  defp summarize_city(city) do
    %{
      city_id: Base.encode16(city.id, case: :lower),
      territory_id: Base.encode16(city.territory_id, case: :lower),
      phase: Atom.to_string(city.phase),
      governance: Atom.to_string(City.governance_type(city)),
      citizen_count: city.citizen_count,
      blocks_unlocked: city.blocks_unlocked,
      treasury_bsv: city.treasury_bsv,
      treasury_bsv_display: sats_to_bsv(city.treasury_bsv),
      founder_tokens_total: city.founder_tokens_total,
      founder_tokens_vested: city.founder_tokens_vested,
      token_supply: city.token_supply,
      ubi_active: City.ubi_active?(city)
    }
  end

  defp summarize_key(key) do
    %{
      id: key["id"],
      pubkey: key["pubkey"],
      address: key["address"]
    }
  end

  defp initial_funding_events(city_fixture, treasury_after_sats) do
    amount = city_fixture["initial_treasury_funding_sats"] || 0

    if amount > 0 do
      [
        %{
          txid: city_fixture["initial_funding_txid"] || "#{city_fixture["slug"]}-initial-funding",
          reason: "initial-treasury-funding",
          amount_sats: amount,
          amount_bsv_display: sats_to_bsv(amount),
          treasury_after_sats: treasury_after_sats,
          treasury_after_bsv_display: sats_to_bsv(treasury_after_sats)
        }
      ]
    else
      []
    end
  end

  defp apply_city_funding(city, amount_sats) when amount_sats > 0 do
    %{city | treasury_bsv: city.treasury_bsv + amount_sats}
  end

  defp apply_city_funding(city, _amount_sats), do: city

  defp fixture_start_height(fixtures) do
    fixtures.topology["start_height"] ||
      fixtures.cities["start_height"] ||
      @default_start_height
  end

  defp load_json!(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp sats_to_bsv(satoshis) do
    satoshis
    |> Kernel./(@sats_per_bsv)
    |> :erlang.float_to_binary(decimals: 8)
  end

  defp unique_values?(values) do
    Enum.uniq(values) == values
  end

  defp build_check(name, passed, details) do
    %{
      name: name,
      passed: passed,
      details: details
    }
  end
end
