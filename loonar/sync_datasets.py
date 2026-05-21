import argparse
import sys
import logging

from superset.app import create_app
from superset.extensions import db
from superset.models.core import Database
from superset.connectors.sqla.models import SqlaTable

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

def main():
    parser = argparse.ArgumentParser(description="Create Superset datasets for all tables in a schema.")
    parser.add_argument("-d", "--database", required=True, help="Name of the Database connection in Superset")
    parser.add_argument("-s", "--schema", required=False, default="public", help="Schema name (default: public)")
    parser.add_argument("-c", "--catalog", required=False, default=None, help="Catalog name (if applicable)")
    
    args = parser.parse_args()

    app = create_app()
    with app.app_context():
        database = db.session.query(Database).filter_by(database_name=args.database).first()
        if not database:
            logger.error(f"Database '{args.database}' not found in Superset!")
            sys.exit(1)

        logger.info(f"Fetching tables for Database '{args.database}' in Schema '{args.schema}'...")
        
        try:
            tables = database.get_all_table_names_in_schema(schema=args.schema, catalog=args.catalog)
        except Exception as e:
            logger.error(f"Failed to fetch tables: {e}")
            sys.exit(1)

        created_count = 0
        for table_name, table_schema, table_catalog in tables:
            existing = db.session.query(SqlaTable).filter_by(
                table_name=table_name, 
                schema=args.schema, 
                database_id=database.id
            ).first()

            if not existing:
                logger.info(f"Creating dataset for table '{table_name}'...")
                dataset = SqlaTable(
                    table_name=table_name,
                    schema=args.schema,
                    catalog=args.catalog,
                    database=database
                )
                db.session.add(dataset)
                
                # Obtém metadados de maneira segura (colunas e tipos)
                try:
                    dataset.fetch_metadata()
                    created_count += 1
                except Exception as e:
                    logger.warning(f"Error fetching metadata for '{table_name}': {e}")
            else:
                logger.debug(f"Dataset for '{table_name}' already exists. Skipping.")
                
        db.session.commit()
        logger.info(f"Process completed. Created {created_count} new dataset(s).")

if __name__ == "__main__":
    main()
