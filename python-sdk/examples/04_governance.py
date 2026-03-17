"""
Example 4: Governance

Demonstrates creating proposals, voting, and execution.
Per spec 04-governance.md:
- Proposal types with different thresholds
- Voting periods and execution delays
- Quorum requirements by phase
"""

from locus import (
    LocusClient,
    GovernanceManager,
    TreasuryManager,
    CityManager,
    ProposeParams,
    ProposalAction,
)


def main():
    client = LocusClient(network='testnet')
    print("Locus Protocol - Governance Example")
    print("=" * 50)

    # Step 1: Proposal thresholds
    print("\n1. Proposal Type Thresholds:")
    proposal_types = ['parameter_change', 'contract_upgrade', 'treasury_spend', 'constitutional', 'emergency']
    for ptype in proposal_types:
        threshold = GovernanceManager.get_threshold(ptype)
        print(f"   {ptype:20s}: {threshold*100:5.1f}%")

    # Step 2: Quorum requirements
    print("\n2. Quorum Requirements by Phase:")
    phases = ['village', 'town', 'city', 'metropolis']
    for phase in phases:
        quorum = GovernanceManager.get_quorum(phase)
        print(f"   {phase:12s}: {quorum*100:.0f}%")

    # Step 3: Governance periods
    print("\n3. Governance Periods (in blocks):")
    print(f"   Discussion: {GovernanceManager.get_discussion_period():,} (~7 days)")
    print(f"   Voting: {GovernanceManager.get_voting_period():,} (~14 days)")
    print(f"   Execution Delay: {GovernanceManager.get_execution_delay():,} (~3 days)")

    # Step 4: Proposal deposit
    deposit = GovernanceManager.get_proposal_deposit()
    print(f"\n4. Proposal Deposit: {deposit:,} sats ({deposit/1e8:.2f} BSV)")

    # Step 5: Create a proposal
    print("\n5. Creating a Proposal...")
    
    proposal = ProposeParams(
        proposal_type='parameter_change',
        title="Reduce Block Auction Period",
        description="Proposal to reduce the block auction period from 48 hours to 24 hours",
        proposer_pubkey='proposer_pubkey',
        scope=1,  # City-wide
        actions=[
            ProposalAction(
                type='update_parameter',
                target='block_auction_period',
                data='86400',  # 24 hours in seconds
            ),
        ],
        deposit=10_000_000,  # 0.1 BSV
    )

    propose_script = GovernanceManager.build_propose_transaction(proposal)
    print(f"   Proposal script: {len(propose_script)} bytes")
    print(f"   Title: {proposal.title}")
    print(f"   Type: {proposal.proposal_type}")

    # Step 6: Voting scenarios
    print("\n6. Voting Scenarios:")
    
    scenarios = [
        ("Parameter Change (51% needed)", 'city', 'parameter_change', 15, 5, 2, 25),
        ("Constitutional (75% needed)", 'city', 'constitutional', 15, 5, 2, 25),
        ("Low Participation", 'city', 'parameter_change', 5, 2, 1, 25),
        ("Metropolis Quorum", 'metropolis', 'parameter_change', 30, 10, 5, 100),
    ]
    
    for desc, phase, ptype, yes, no, abstain, citizens in scenarios:
        result = GovernanceManager.tally(yes, no, abstain, citizens, phase, ptype)
        threshold = GovernanceManager.get_threshold(ptype)
        quorum = GovernanceManager.get_quorum(phase)
        total_votes = yes + no + abstain
        participation = total_votes / citizens * 100
        
        print(f"\n   {desc}")
        print(f"      Votes: {yes}Y / {no}N / {abstain}A (out of {citizens} citizens)")
        print(f"      Participation: {participation:.1f}% (quorum: {quorum*100:.0f}%)")
        print(f"      Result: {result.upper()}")

    # Step 7: Cast votes
    print("\n7. Casting Votes...")
    
    votes = ['yes', 'no', 'abstain']
    for vote in votes:
        vote_script = GovernanceManager.build_vote_transaction(
            proposal_id='proposal_123',
            voter_pubkey=f'voter_{vote}_pubkey',
            vote=vote,  # type: ignore
        )
        print(f"   {vote:8s} vote script: {len(vote_script)} bytes")

    # Step 8: Execution eligibility
    print("\n8. Execution Eligibility:")
    
    voting_ended = 800_000
    scenarios = [
        (800_100, 'parameter_change', 'Normal (needs delay)'),
        (800_432, 'parameter_change', 'After delay'),
        (800_001, 'emergency', 'Emergency (no delay)'),
    ]
    
    for current, ptype, desc in scenarios:
        can_exec = GovernanceManager.can_execute(voting_ended, current, ptype)
        status = "✓ Can execute" if can_exec else "✗ Cannot execute"
        print(f"   {desc:25s}: {status}")

    # Step 9: Execute proposal
    print("\n9. Executing Proposal...")
    
    exec_script = GovernanceManager.build_execute_transaction(
        proposal_id='proposal_123',
        executor_pubkey='executor_pubkey',
    )
    print(f"   Execute script: {len(exec_script)} bytes")

    # Step 10: Genesis era check
    print("\n10. Genesis Era Status:")
    print(f"    Block 1,000,000: {'In Genesis Era' if GovernanceManager.is_genesis_era(1_000_000) else 'Post Genesis'}")
    print(f"    Block 2,500,000: {'In Genesis Era' if GovernanceManager.is_genesis_era(2_500_000) else 'Post Genesis'}")

    print("\n" + "=" * 50)
    print("Governance Flow:")
    print("1. Create proposal with deposit")
    print("2. Discussion period (~7 days)")
    print("3. Voting period (~14 days)")
    print("4. Tally votes (check threshold + quorum)")
    print("5. Execution delay (~3 days, except emergency)")
    print("6. Execute proposal")


if __name__ == "__main__":
    main()
