#!/usr/bin/env python3
"""
Quick test to verify token-related fixes work correctly.
Run with: python test_token_fixes.py
"""

import sys
import os
from datetime import datetime, timedelta, timezone

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

def test_token_creation_and_validation():
    """Test creating and validating tokens"""
    try:
        from auth import create_access_token, decode_token
        from config import JWT_EXPIRES_MINUTES
        
        print("✓ Imports successful")
        
        # Create a token
        token = create_access_token("1")
        print(f"✓ Token created: {token[:50]}...")
        
        # Decode it
        sub = decode_token(token)
        print(f"✓ Token decoded: user_id={sub}")
        
        # Check token expiration
        import json
        import base64
        parts = token.split('.')
        if len(parts) != 3:
            print("✗ Token format invalid")
            return False
        
        # Decode payload (add padding)
        payload_b64 = parts[1]
        # Add padding if needed
        padding = 4 - len(payload_b64) % 4
        if padding != 4:
            payload_b64 += '=' * padding
        
        try:
            payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        except Exception as e:
            print(f"✗ Could not decode payload: {e}")
            return False
        
        iat = payload.get('iat')
        exp = payload.get('exp')
        now = int(datetime.now(timezone.utc).timestamp())
        
        print(f"✓ Token issued at: {datetime.fromtimestamp(iat, tz=timezone.utc)}")
        print(f"✓ Token expires at: {datetime.fromtimestamp(exp, tz=timezone.utc)}")
        print(f"✓ Current time: {datetime.fromtimestamp(now, tz=timezone.utc)}")
        
        # Check expiration is ~90 days
        remaining_seconds = exp - now
        remaining_days = remaining_seconds / (24 * 3600)
        print(f"✓ Token valid for: {remaining_days:.1f} days (expected: ~90 days)")
        
        if remaining_days < 85 or remaining_days > 95:
            print(f"⚠ Warning: Token expiration not ~90 days!")
            return False
        
        print(f"✓ Token configuration correct: JWT_EXPIRES_MINUTES={JWT_EXPIRES_MINUTES}")
        
        return True
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_error_messages():
    """Test that enhanced error messages work"""
    try:
        from auth import decode_token
        
        # Try to decode an invalid token
        try:
            decode_token("invalid.token.here")
            print("✗ Should have raised error for invalid token")
            return False
        except ValueError as e:
            error_msg = str(e)
            if "Token decode error:" in error_msg or "Invalid token:" in error_msg:
                print(f"✓ Error message enhanced: {error_msg[:80]}...")
                return True
            else:
                print(f"✗ Error message not enhanced: {error_msg}")
                return False
    except Exception as e:
        print(f"✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("=" * 60)
    print("Token Fix Verification Test")
    print("=" * 60)
    
    print("\n1. Testing token creation and validation...")
    test1 = test_token_creation_and_validation()
    
    print("\n2. Testing enhanced error messages...")
    test2 = test_error_messages()
    
    print("\n" + "=" * 60)
    if test1 and test2:
        print("✓ ALL TESTS PASSED")
        print("=" * 60)
        return 0
    else:
        print("✗ SOME TESTS FAILED")
        print("=" * 60)
        return 1

if __name__ == '__main__':
    sys.exit(main())
