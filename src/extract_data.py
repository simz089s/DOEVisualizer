#!/usr/bin/python
import sqlite3


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
            print()
            break
        names = row.keys()
        for colname, rowval in zip(names, row):
            print(f"{colname} = {rowval}")
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
