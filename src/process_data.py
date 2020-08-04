import sqlite3
import numpy as np
import scipy as sp
import pandas as pd
# from matplotlib import pyplot as plt
# import sklearn
# import torch


def sqldb_to_df(conn, query="", table=""):
    if table:# and conn is sqlalchemy
        return pd.read_sql_table(table, conn)
    elif query:
        return pd.read_sql_query(query, conn, index_col="ID")


def fishbone(data):
    return

ishikawa = fishbone


def main():
    return

if __name__ == "__main__":
    main()
