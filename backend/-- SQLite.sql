-- SQLite
UPDATE users
SET role = 'admin'
WHERE email = 'admin@';

SELECT id, username, email, role FROM users;