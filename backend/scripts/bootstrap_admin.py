import argparse

from sqlalchemy.orm import Session

from database import SessionLocal
from models import User


def main():
    parser = argparse.ArgumentParser(description="Promote a user to admin by username/email.")
    parser.add_argument("--username", default=None)
    parser.add_argument("--email", default=None)
    args = parser.parse_args()

    if not args.username and not args.email:
        raise SystemExit("Provide --username or --email")

    db: Session = SessionLocal()
    try:
        q = db.query(User)
        if args.username:
            q = q.filter(User.username == args.username)
        if args.email:
            q = q.filter(User.email == args.email)
        user = q.first()
        if not user:
            raise SystemExit("User not found")

        user.role = "admin"
        db.commit()
        print(f"Promoted user id={user.id} username={user.username} to admin")
    finally:
        db.close()


if __name__ == "__main__":
    main()

