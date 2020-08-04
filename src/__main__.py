#!/usr/bin/python
import io
import numpy as np
import scipy as sp
import pandas as pd
# import sqlalchemy
# from matplotlib import pyplot as plt
# import sklearn
# import torch

import extract_data as myed
import process_data as mypd


def get_MAP_ADI_RET():
    with io.open("../res/datasets/dataset_info.txt", "r", encoding="utf-8") as file:
        filename = file.readline().strip()
        cols = file.readline().strip().split(",")
        df = myed.extract_csv("../res/datasets/"+filename, " ", cols, None)
        print(df)
        return df


def put_MAP_ADI_RET_db(conn, df):
    # df.to_sql('MAP_DATA_ADI_RETAINED_AUSTENITE', con=conn, if_exists='append', index=True, index_label='ID', chunksize=10000)
    df.to_sql('MAP_DATA_ADI_RETAINED_AUSTENITE', con=conn, if_exists='replace', index=True, index_label='ID', chunksize=10000)
    myed.print_table(conn, "MAP_DATA_ADI_RETAINED_AUSTENITE", 10)


def main():
    with myed.connect_db() as conn:
        df = get_MAP_ADI_RET()
        put_MAP_ADI_RET_db(conn, df)
        df = mypd.sqldb_to_df(conn, "select * from MAP_DATA_ADI_RETAINED_AUSTENITE;")
        print(df)
    return

if __name__ == "__main__":
    main()
