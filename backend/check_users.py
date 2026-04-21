import sqlite3

conn = sqlite3.connect('users.db')
cur = conn.cursor()

print("=" * 60)
print("USERS IN DATABASE")
print("=" * 60)

cur.execute("SELECT id, username, email, role, created_at FROM users ORDER BY id")
users = cur.fetchall()

if users:
    print(f"\nTotal users: {len(users)}\n")
    for row in users:
        print(f"ID: {row[0]}")
        print(f"  Username: {row[1]}")
        print(f"  Email: {row[2]}")
        print(f"  Role: {row[3]}")
        print(f"  Created: {row[4]}")
        print()
else:
    print("No users found in database")

conn.close()
