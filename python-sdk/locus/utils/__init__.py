"""
Locus Protocol Utilities

Utility functions for Fibonacci sequence calculations,
stake calculations, and MessagePack encoding.
"""

from .fibonacci import (
    fibonacci_sequence,
    fibonacci_sum,
    blocks_for_citizens,
    phase_for_citizens,
    governance_for_phase,
    phase_number,
)

from .stakes import (
    stake_for_level,
    stake_for_object_type,
    calculate_lock_height,
    calculate_penalty,
    calculate_emergency_return,
    progressive_tax,
)

from .messagepack import encode, decode

__all__ = [
    # Fibonacci
    "fibonacci_sequence",
    "fibonacci_sum",
    "blocks_for_citizens",
    "phase_for_citizens",
    "governance_for_phase",
    "phase_number",
    # Stakes
    "stake_for_level",
    "stake_for_object_type",
    "calculate_lock_height",
    "calculate_penalty",
    "calculate_emergency_return",
    "progressive_tax",
    # MessagePack
    "encode",
    "decode",
]
