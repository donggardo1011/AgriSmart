import sqlite3
conn = sqlite3.connect('users.db')
cur = conn.cursor()
for row in cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table'"):
    print(row[0])
    print(row[1])
    print('---')
conn.close()
