import sqlite3
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Account information
accounts = [
    {
        "username": "edgarestenzo",
        "password": "admin123",
        "email": "edgarestenzo21@gmail.com",
        "role": "user"
    },
    {
        "username": "renzogabonada",
        "password": "user123",
        "email": "2301101205@student.buksu.edu.ph",
        "role": "user"
    }
]

conn = sqlite3.connect('users.db')
cur = conn.cursor()

print("=" * 70)
print("CREATING USER ACCOUNTS")
print("=" * 70)

for account in accounts:
    # Check if user already exists
    cur.execute("SELECT id FROM users WHERE username = ?", (account['username'],))
    if cur.fetchone():
        print(f"\n⚠ User '{account['username']}' already exists - skipping")
        continue
    
    # Hash password
    hashed_password = pwd_context.hash(account['password'])
    
    # Insert user
    try:
        cur.execute(
            "INSERT INTO users (username, email, password, role) VALUES (?, ?, ?, ?)",
            (account['username'], account['email'], hashed_password, account['role'])
        )
        conn.commit()
        print(f"\n✓ Created user: {account['username']}")
        print(f"  Email: {account['email']}")
        print(f"  Role: {account['role']}")
        print(f"  Password: {'*' * len(account['password'])}")
    except Exception as e:
        print(f"\n✗ Error creating {account['username']}: {e}")
        conn.rollback()

# Display all users
print("\n" + "=" * 70)
print("ALL USERS IN DATABASE")
print("=" * 70)

cur.execute("SELECT id, username, email, role FROM users ORDER BY id")
users = cur.fetchall()

for row in users:
    print(f"\nID: {row[0]}")
    print(f"  Username: {row[1]}")
    print(f"  Email: {row[2]}")
    print(f"  Role: {row[3]}")

conn.close()
print("\n✓ Done!")
