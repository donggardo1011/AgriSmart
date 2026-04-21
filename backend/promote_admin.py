import sqlite3

conn = sqlite3.connect('users.db')
cur = conn.cursor()

print("=" * 70)
print("PROMOTING USER TO ADMIN")
print("=" * 70)

# Update edgarestenzo to admin role
username = "edgarestenzo"
cur.execute("UPDATE users SET role = 'admin' WHERE username = ?", (username,))
conn.commit()

# Verify the change
cur.execute("SELECT id, username, email, role FROM users WHERE username = ?", (username,))
user = cur.fetchone()

if user:
    print(f"\n✓ User promoted to admin!")
    print(f"  ID: {user[0]}")
    print(f"  Username: {user[1]}")
    print(f"  Email: {user[2]}")
    print(f"  Role: {user[3]}")
else:
    print(f"\n✗ User '{username}' not found")

# Show all users
print("\n" + "=" * 70)
print("ALL USERS AND ROLES")
print("=" * 70)

cur.execute("SELECT id, username, email, role FROM users ORDER BY id")
users = cur.fetchall()

for row in users:
    role_badge = "👑 ADMIN" if row[3] == "admin" else "👤 USER"
    print(f"\n{role_badge}")
    print(f"  ID: {row[0]} | Username: {row[1]}")
    print(f"  Email: {row[2]}")

conn.close()
print("\n✓ Done!")
