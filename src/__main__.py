#!/usr/bin/python
import os, io
from itertools import combinations
import numpy as np
import scipy as sp
import pandas as pd
# import sqlalchemy
from matplotlib import pyplot as plt
# import pylab
# import sklearn
# import torch

import extract_data as myed
import process_data as mypd


dirname = os.path.dirname(os.path.abspath(__file__))


def get_MAP_ADI_RET():
    with io.open(os.path.join(dirname, "..", "res", "datasets", "dataset_info.txt"), "r", encoding="utf-8") as file:
        filename = file.readline().strip()
        cols = file.readline().strip().split(",")
        df = myed.extract_csv(os.path.join(dirname, "..", "res", "datasets", filename), " ", cols, None)
        print(df)
        return df


def put_MAP_ADI_RET_db(conn, df):
    # df.to_sql('MAP_DATA_ADI_RETAINED_AUSTENITE', con=conn, if_exists='append', index=True, index_label='ID', chunksize=10000)
    df.to_sql('MAP_DATA_ADI_RETAINED_AUSTENITE', con=conn, if_exists='replace', index=True, index_label='ID', chunksize=10000)
    # myed.print_table(conn, "MAP_DATA_ADI_RETAINED_AUSTENITE", 10)


def graph_pairs(df):
    # x_df = df.iloc[:,0]
    # y_df = df.iloc[:,1]
    n = 3
    _, n = df.shape
    for pair in combinations(range(n-1), 2):
        mypd.plot_pair(df, pair[0], pair[1], f"{df.columns.values[pair[0]]}\nvs\n{df.columns.values[pair[1]]}")
    plt.show()


def main():
    with myed.connect_db(os.path.join(dirname, "..", "db.db")) as conn:
        df = get_MAP_ADI_RET()
        # put_MAP_ADI_RET_db(conn, df)
        df = mypd.sqldb_to_df(conn, "select * from MAP_DATA_ADI_RETAINED_AUSTENITE;")
        print(df)
        graph_pairs(df)
    return

if __name__ == "__main__":
    main()
