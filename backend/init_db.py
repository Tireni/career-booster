"""Create the account table using the configured XAMPP database user."""
from app.auth import init_database

if __name__ == '__main__':
    init_database()
    print('Account table is ready.')
