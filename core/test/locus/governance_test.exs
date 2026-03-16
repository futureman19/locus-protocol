defmodule Locus.GovernanceTest do
  use ExUnit.Case, async: false

  alias Locus.Governance
  alias Locus.Schemas.{City, Proposal}

  setup do
    # Restart Governance GenServer for clean state
    if Process.whereis(Locus.Governance) do
      GenServer.stop(Locus.Governance)
    end
    {:ok, _pid} = Governance.start_link([])
    :ok
  end

  describe "create_proposal/4" do
    test "founder can propose in genesis phase" do
      city = build_city(:genesis, 1)

      {:ok, proposal} = Governance.create_proposal(city, "founder", %{
        proposal_type: :parameter_change,
        title: "Change policy",
        description: "Test"
      }, 800_000)

      # In founder governance, proposals auto-pass
      assert proposal.status == :passed
      assert proposal.proposer_pubkey == "founder"
      assert proposal.deposit == 10_000_000
    end

    test "non-founder cannot propose in genesis phase" do
      city = build_city(:genesis, 1)

      assert {:error, :unauthorized} = Governance.create_proposal(city, "citizen_2", %{
        proposal_type: :parameter_change,
        title: "Unauthorized"
      }, 800_000)
    end

    test "citizen can propose in city phase (direct democracy)" do
      city = build_city(:city, 25)

      {:ok, proposal} = Governance.create_proposal(city, "citizen_5", %{
        proposal_type: :treasury_spend,
        title: "Fund project"
      }, 800_000)

      assert proposal.status == :active
      assert proposal.proposal_type == :treasury_spend
    end

    test "rejects invalid proposal type" do
      city = build_city(:city, 25)

      assert {:error, :invalid_proposal_type} = Governance.create_proposal(city, "citizen_5", %{
        proposal_type: :nonsense
      }, 800_000)
    end
  end

  describe "vote/5" do
    test "citizens can vote on active proposals" do
      city = build_city(:city, 25)

      {:ok, proposal} = Governance.create_proposal(city, "citizen_1", %{
        proposal_type: :parameter_change,
        title: "Vote test"
      }, 800_000)

      # Vote after discussion period (7 days = 1008 blocks)
      vote_height = 800_000 + 1_100

      {:ok, updated} = Governance.vote(proposal.id, "citizen_2", city, :yes, vote_height)
      assert updated.votes_for == 1
      assert "citizen_2" in updated.voters
    end

    test "rejects vote in founder governance" do
      city = build_city(:genesis, 1)

      {:ok, proposal} = Governance.create_proposal(city, "founder", %{
        proposal_type: :parameter_change, title: "Test"
      }, 800_000)

      assert {:error, :founder_governance} =
        Governance.vote(proposal.id, "citizen_2", city, :yes, 800_100)
    end

    test "rejects duplicate votes" do
      city = build_city(:city, 25)

      {:ok, proposal} = Governance.create_proposal(city, "citizen_1", %{
        proposal_type: :parameter_change, title: "Test"
      }, 800_000)

      vote_height = 800_000 + 1_100
      {:ok, _} = Governance.vote(proposal.id, "citizen_2", city, :yes, vote_height)

      assert {:error, :already_voted} =
        Governance.vote(proposal.id, "citizen_2", city, :no, vote_height)
    end

    test "rejects vote during discussion period" do
      city = build_city(:city, 25)

      {:ok, proposal} = Governance.create_proposal(city, "citizen_1", %{
        proposal_type: :parameter_change, title: "Test"
      }, 800_000)

      assert {:error, :discussion_period} =
        Governance.vote(proposal.id, "citizen_2", city, :yes, 800_100)
    end
  end

  describe "tally/2" do
    test "passes with 51% for parameter_change" do
      city = build_city(:city, 25)

      proposal = %Proposal{
        proposal_type: :parameter_change,
        votes_for: 8,
        votes_against: 2,
        votes_abstain: 1,
        voters: Enum.map(1..11, &"citizen_#{&1}")
      }

      assert Governance.tally(proposal, city) == :passed
    end

    test "rejects when below threshold" do
      city = build_city(:city, 25)

      proposal = %Proposal{
        proposal_type: :parameter_change,
        votes_for: 3,
        votes_against: 8,
        votes_abstain: 0,
        voters: Enum.map(1..11, &"citizen_#{&1}")
      }

      assert Governance.tally(proposal, city) == :rejected
    end

    test "pending when quorum not met" do
      city = build_city(:city, 25)

      proposal = %Proposal{
        proposal_type: :parameter_change,
        votes_for: 3,
        votes_against: 0,
        votes_abstain: 0,
        voters: ["citizen_1", "citizen_2", "citizen_3"]
      }

      # 40% quorum for city phase = 10 votes needed, only 3
      assert Governance.tally(proposal, city) == :pending
    end

    test "constitutional requires 75%" do
      city = build_city(:city, 25)

      # 60% yes → passes 51% but fails 75%
      proposal = %Proposal{
        proposal_type: :constitutional,
        votes_for: 7,
        votes_against: 4,
        votes_abstain: 0,
        voters: Enum.map(1..11, &"citizen_#{&1}")
      }

      # 7/11 = 63.6% < 75%
      assert Governance.tally(proposal, city) == :rejected
    end
  end

  describe "execute/3" do
    test "executes a passed proposal after delay" do
      proposal = %Proposal{
        status: :passed,
        proposal_type: :parameter_change,
        voting_ends_at: 800_000
      }

      # Execution delay = 432 blocks (3 days)
      assert {:error, :execution_delay_not_met} =
        Governance.execute(proposal, 800_100)

      {:ok, executed} = Governance.execute(proposal, 800_500, txid: "exec_txid")
      assert executed.status == :executed
      assert executed.execution_txid == "exec_txid"
    end

    test "emergency proposals execute without delay" do
      proposal = %Proposal{
        status: :passed,
        proposal_type: :emergency,
        voting_ends_at: 800_000
      }

      {:ok, executed} = Governance.execute(proposal, 800_001)
      assert executed.status == :executed
    end
  end

  describe "quorum_for_phase/1" do
    test "returns correct quorum per phase" do
      assert Governance.quorum_for_phase(:village) == 0.67
      assert Governance.quorum_for_phase(:town) == 0.60
      assert Governance.quorum_for_phase(:city) == 0.40
      assert Governance.quorum_for_phase(:metropolis) == 0.51
    end
  end

  describe "genesis_era?/1" do
    test "true before block 2,100,000" do
      assert Governance.genesis_era?(0)
      assert Governance.genesis_era?(2_099_999)
    end

    test "false at/after block 2,100,000" do
      refute Governance.genesis_era?(2_100_000)
      refute Governance.genesis_era?(3_000_000)
    end
  end

  # Helpers

  defp build_city(phase, citizen_count) do
    citizens = if citizen_count > 0 do
      ["founder" | Enum.map(2..citizen_count, &"citizen_#{&1}")]
    else
      []
    end

    %City{
      id: "city_test",
      name: "Test City",
      territory_id: <<0::256>>,
      founder_pubkey: "founder",
      founded_at: 0,
      phase: phase,
      citizens: citizens,
      citizen_count: citizen_count,
      treasury_bsv: 100_000_000_000,
      token_supply: 3_200_000,
      treasury_tokens: 1_600_000,
      founder_tokens_total: 640_000
    }
  end
end
