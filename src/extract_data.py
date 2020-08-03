import sqlite3
import pandas as pd
# import sqlalchemy


def connect_db(pathdb="../db.db"):
    connection = sqlite3.connect(pathdb)
    if connection:
        print('Successfully connected to', connection)
    return connection


def print_table(conn, tblname, n=-1):
    cursor = conn.execute(f'''
        select *
        from {tblname}
        ;
    ''')
    cursor.row_factory = sqlite3.Row
    for row in cursor:
        if n == 0:
            break
        names = row.keys()
        for colname, rowval in zip(names, row):
            print(f"{colname} = {rowval}")
        print()
        n -= 1


def insert_row(conn, tablename, rowvals):
    query = f"""
        INSERT
            INTO {tablename}
            VALUES {rowvals}
        ;
    """
    cursor = conn.execute(query)

def insert_row_commit(conn, tablename, rowvals):
    insert_row(conn, tablename, rowvals)
    conn.commit()


def extract_csv(filename, sep, cols, na_values):
    if sep == ' ':
        df = pd.read_csv(filename, names=cols, usecols=cols, na_values=na_values, skipinitialspace=True, delim_whitespace=True)[cols]
    else:
        df = pd.read_csv(filename, names=cols, usecols=cols, na_values=na_values, skipinitialspace=True, delimiter=sep)[cols]
    df.dropna(how='any', inplace=True)
    return df


def main():
    try:
        with connect_db() as conn:
            print_table(conn, "tblTest", 3)
            # insert_row_commit(conn, 'tblTest', '(1, 123456)')
            # print_table(conn, "tblTest")
    finally:
        # conn.close()
        return

if __name__ == "__main__":
    main()
