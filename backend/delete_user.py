"""Explicit admin utility. Never selects a target account implicitly."""
import argparse
from uuid import UUID


def main():
    parser = argparse.ArgumentParser(description="Delete one explicitly selected Supabase auth account")
    parser.add_argument("--user-id", required=True, type=UUID)
    parser.add_argument("--confirm-user-id", required=True, type=UUID)
    args = parser.parse_args()
    if args.user_id != args.confirm_user_id:
        parser.error("Confirmation must match the exact user ID")
    from app.core.db import get_db
    get_db().auth.admin.delete_user(str(args.user_id))
    print("Requested account deleted. Complete configured external storage/checkpoint retention cleanup separately.")


if __name__ == "__main__":
    main()
