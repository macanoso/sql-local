# sql-local

A local MySQL database setup for trials and testing.

## Quick Start

### 1. Start MySQL Database

Start the MySQL container using Docker Compose:

```bash
docker-compose up -d
```

This will start a MySQL 8.0 instance with:
- **Host**: localhost
- **Port**: 3306
- **Root Password**: rootpassword
- **Database**: trial_db
- **User**: trial_user
- **Password**: trial_password

### 2. Install Dependencies

Install Python dependencies using `uv`:

```bash
uv sync
```

### 3. Test Connection

Test the database connection:

```bash
uv run python db_config.py
```

### 4. Run Example

Run the example script to create a sample table and insert data:

```bash
uv run python example_usage.py
```

## Configuration

You can customize the database configuration by creating a `.env` file:

```bash
cp .env.example .env
```

Then edit `.env` with your preferred settings.

## Database Management

### Stop the Database

```bash
docker-compose down
```

### Stop and Remove Data

```bash
docker-compose down -v
```

### View Logs

```bash
docker-compose logs -f mysql
```

### Access MySQL CLI

```bash
docker exec -it sql-local-mysql mysql -u trial_user -ptrial_password trial_db
```

Or as root:

```bash
docker exec -it sql-local-mysql mysql -u root -prootpassword
```

## Usage in Your Code

```python
from db_config import get_connection

# Get a connection
connection = get_connection()
cursor = connection.cursor()

# Execute queries
cursor.execute("SELECT * FROM your_table")
results = cursor.fetchall()

# Don't forget to close
cursor.close()
connection.close()
```

## Notes

- Data persists in a Docker volume named `mysql_data`
- The database is accessible on `localhost:3306`
- Default credentials are for local development only