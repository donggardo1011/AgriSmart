import sqlite3

conn = sqlite3.connect('users.db')
cur = conn.cursor()

# Check if admin user exists
cur.execute("SELECT * FROM users WHERE username = 'admin'")
if cur.fetchone():
    print("✓ Admin user already exists")
else:
    # Use the generated bcrypt hash for admin123
    hashed_password = "$2b$12$aJQ3VLjOSgd/sPFkMzVja.agoV0/ncYbMKir/nLjtyf3zOQ5UGUdC"
    
    cur.execute(
        "INSERT INTO users (username, email, password, role) VALUES (?, ?, ?, ?)",
        ('admin', 'admin@agrismart.local', hashed_password, 'admin')
    )
    conn.commit()
    print("✓ Admin user created!")
    print("  Username: admin")
    print("  Email: admin@agrismart.local") 
    print("  Password: admin123")
    print("  Role: admin")

# Check all users
print("\nUsers in database:")
cur.execute("SELECT id, username, email, role FROM users")
for row in cur.fetchall():
    print(f"  ID: {row[0]}, Username: {row[1]}, Email: {row[2]}, Role: {row[3]}")

conn.close()

