import sqlite3
conn = sqlite3.connect('users.db')
cur = conn.cursor()
cur.execute('SELECT id, version, file_path, is_active, map_score, precision, recall, f1_score, classes, description FROM model_versions ORDER BY id')
rows = cur.fetchall()
for row in rows:
    print(row)
print('---')
cur.execute('SELECT id, version, file_path, is_active FROM model_versions WHERE is_active=1')
active = cur.fetchall()
print('active:', active)
conn.close()
