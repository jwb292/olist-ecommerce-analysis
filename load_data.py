import os
from pathlib import Path
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# Load database credentials from .env
load_dotenv()

# Build connection URL safely
connection_url = URL.create(
    drivername="postgresql",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", 5432)),
    database=os.getenv("DB_NAME", "olist_db"),
)

engine = create_engine(connection_url)

# Test PostgreSQL Connection
try:
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1;"))
        print("Database connection test successful!")
except Exception as e:
    print(f"Connection failed: {e}")
    exit()

# Test the connection
try:
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1;"))
        print("Connection to the database was successful!")
except Exception as e: 
    print(f"Connection failed: {e}")
    exit()

# Load CSV files into PostgreSQL
raw_data_path = Path("data/raw")

for file_path in raw_data_path.glob("*csv"):
    # Clean table name by removing _dataset.csv
    table_name = file_path.stem.replace("_dataset", "")
    print(f"Loading {file_path} into table {table_name}...")
    df = pd.read_csv(file_path)
    df.to_sql(name=table_name, con=engine, if_exists="replace", index=False)
    
print("All CSV files have been loaded into the PostgreSQL database.")
