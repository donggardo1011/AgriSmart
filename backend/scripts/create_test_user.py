#!/usr/bin/env python3
"""Create a test user for development."""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import SessionLocal
from models import User
from auth import hash_password

def create_test_user():
    db = SessionLocal()
    try:
        # Check if user already exists
        existing = db.query(User).filter(User.username == 'admin').first()
        if existing:
            print("✓ Test user 'admin' already exists")
            return

        # Create admin user
        admin = User(
            username='admin',
            email='admin@agrismart.local',
            password=hash_password('admin123'),
            role='admin'
        )
        db.add(admin)
        db.commit()
        print("✓ Created test admin user:")
        print(f"  Username: admin")
        print(f"  Password: admin123")
        print(f"  Role: admin")
    except Exception as e:
        print(f"✗ Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == '__main__':
    create_test_user()
