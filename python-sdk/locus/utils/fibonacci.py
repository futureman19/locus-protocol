"""
Fibonacci Sequence Calculations

Fibonacci sequence calculations for city block unlocking.

Per spec 02-city-lifecycle.md:
- Blocks unlock based on CITIZEN COUNT
- Sequence: 1, 1, 2, 3, 5, 8, 13, 21, 34...
"""

from typing import List, Literal

CityPhase = Literal[
    "genesis",
    "settlement", 
    "village",
    "town",
    "city",
    "metropolis",
]

GovernanceType = Literal[
    "founder",
    "tribal_council",
    "republic",
    "direct_democracy",
    "senate",
]


def fibonacci_sequence(n: int) -> List[int]:
    """
    Returns the first n Fibonacci numbers.
    
    Args:
        n: Number of Fibonacci numbers to generate
        
    Returns:
        List of first n Fibonacci numbers
        
    Example:
        >>> fibonacci_sequence(5)
        [1, 1, 2, 3, 5]
    """
    if n <= 0:
        return []
    if n == 1:
        return [1]
    if n == 2:
        return [1, 1]
    
    result = [1, 1]
    for i in range(2, n):
        result.append(result[i - 1] + result[i - 2])
    return result


def fibonacci_sum(n: int) -> int:
    """
    Returns the sum of the first n Fibonacci numbers.
    
    Args:
        n: Number of Fibonacci numbers to sum
        
    Returns:
        Sum of first n Fibonacci numbers
        
    Example:
        >>> fibonacci_sum(5)
        12  # 1+1+2+3+5
    """
    return sum(fibonacci_sequence(n))


def blocks_for_citizens(citizen_count: int) -> int:
    """
    Returns the number of /16 blocks unlocked for a given citizen count.
    
    Per spec 02-city-lifecycle.md:
    | Citizens | Blocks | Phase       |
    |----------|--------|-------------|
    | 1        | 2      | Genesis     |
    | 2-3      | 2      | Settlement  |
    | 4-8      | 5      | Village     |
    | 9-20     | 8      | Town        |
    | 21-50    | 16     | City        |
    | 51+      | 24     | Metropolis  |
    
    Args:
        citizen_count: Number of citizens in the city
        
    Returns:
        Number of unlocked /16 blocks
        
    Example:
        >>> blocks_for_citizens(25)
        16
    """
    if citizen_count >= 51:
        return 24
    if citizen_count >= 21:
        return 16
    if citizen_count >= 9:
        return 8
    if citizen_count >= 4:
        return 5
    if citizen_count >= 1:
        return 2
    return 0


def phase_for_citizens(citizen_count: int) -> CityPhase | Literal["none"]:
    """
    Returns the city phase based on citizen count.
    
    Per spec 02-city-lifecycle.md:
    - Phase 0 Genesis:    1 citizen
    - Phase 1 Settlement: 2-3 citizens
    - Phase 2 Village:    4-8 citizens
    - Phase 3 Town:       9-20 citizens
    - Phase 4 City:       21-50 citizens
    - Phase 5 Metropolis: 51+ citizens
    
    Args:
        citizen_count: Number of citizens in the city
        
    Returns:
        City phase or 'none' if no citizens
        
    Example:
        >>> phase_for_citizens(25)
        'city'
    """
    if citizen_count >= 51:
        return "metropolis"
    if citizen_count >= 21:
        return "city"
    if citizen_count >= 9:
        return "town"
    if citizen_count >= 4:
        return "village"
    if citizen_count >= 2:
        return "settlement"
    if citizen_count >= 1:
        return "genesis"
    return "none"


def governance_for_phase(phase: CityPhase) -> GovernanceType:
    """
    Returns the governance type for a given phase.
    
    Per spec 02-city-lifecycle.md:
    - Genesis/Settlement: Founder
    - Village:            Tribal Council
    - Town:               Republic
    - City:               Direct Democracy
    - Metropolis:         Senate
    
    Args:
        phase: City phase
        
    Returns:
        Governance type for the phase
        
    Example:
        >>> governance_for_phase('city')
        'direct_democracy'
    """
    mapping: dict[CityPhase, GovernanceType] = {
        "genesis": "founder",
        "settlement": "founder",
        "village": "tribal_council",
        "town": "republic",
        "city": "direct_democracy",
        "metropolis": "senate",
    }
    return mapping[phase]


def phase_number(phase: CityPhase) -> int:
    """
    Returns the phase number (0-5) for a phase name.
    
    Args:
        phase: City phase
        
    Returns:
        Phase number (0=genesis, 5=metropolis)
        
    Example:
        >>> phase_number('city')
        4
    """
    phases: List[CityPhase] = [
        "genesis",
        "settlement",
        "village",
        "town",
        "city",
        "metropolis",
    ]
    return phases.index(phase)
