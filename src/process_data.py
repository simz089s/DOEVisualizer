import sqlite3
import numpy as np
import scipy as sp
import pandas as pd
from matplotlib import pyplot as plt
# import pylab
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


def plot_pair(df, x, y, title):
    graph = df.plot(
        x=x,
        y=y,
        kind='scatter',
        title=title
        # label=[df.columns.values[i] for i in (x, y)]
        )
    graph.plot()
    # ax = plt.gca()
    # x_df.plot(x=None, y=None, kind='scatter', label=x_df.name, ax=ax, color='lime')
    # y_df.plot(x=None, y=None, kind='scatter', label=y_df.name, ax=ax, color='red')
    # plt.show()


def main():
    return

if __name__ == "__main__":
    main()
