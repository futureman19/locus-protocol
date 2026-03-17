"""
MessagePack Encoding/Decoding

All Locus protocol payloads use MessagePack per spec 07-transaction-formats.md.

This module provides a thin wrapper around msgpack-python with proper
type handling for the protocol's needs.
"""

from typing import Any, Dict
import msgpack


def encode(data: Dict[str, Any]) -> bytes:
    """
    Encodes a dictionary to MessagePack binary.
    
    Args:
        data: Dictionary to encode
        
    Returns:
        MessagePack encoded bytes
        
    Example:
        >>> encode({"name": "Neo-Tokyo", "stake": 3200000000})
        b'\x82\xa4name\xa9Neo-Tokyo\xa5stake\xce\xbe...'
    """
    return msgpack.packb(data, use_bin_type=True)


def decode(buffer: bytes) -> Dict[str, Any]:
    """
    Decodes MessagePack binary to a dictionary.
    
    Args:
        buffer: MessagePack encoded bytes
        
    Returns:
        Decoded dictionary
        
    Example:
        >>> decode(b'\x82\xa4name\xa9Neo-Tokyo...')
        {"name": "Neo-Tokyo", "stake": 3200000000}
    """
    return msgpack.unpackb(buffer, raw=False)
