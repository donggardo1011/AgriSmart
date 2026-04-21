import sqlite3

print("=" * 70)
print("CHECKING OLD DATABASE: ../users.db")
print("=" * 70)

try:
    conn = sqlite3.connect('../users.db')
    cur = conn.cursor()

    cur.execute("SELECT id, username, email, role, created_at FROM users ORDER BY id")
    users = cur.fetchall()

    if users:
        print(f"\nTotal users found: {len(users)}\n")
        for row in users:
            print(f"ID: {row[0]}")
            print(f"  Username: {row[1]}")
            print(f"  Email: {row[2]}")
            print(f"  Role: {row[3]}")
            print(f"  Created: {row[4]}")
            print()
    else:
        print("No users found")
    
    conn.close()
    print("✓ Successfully read old database")
except Exception as e:
    print(f"✗ Error: {e}")
