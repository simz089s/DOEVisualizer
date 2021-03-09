module DOEVDBManager

using SQLite
using DataFrames

export get_data, put_data

function get_data(db, query)
    DBInterface.execute(db, query) |> DataFrame
end

function put_data(db, df, tablename)
    df |> SQLite.load!(db, tablename)
end

function test(dbpath, tablename, df)
    db = SQLite.DB(dbpath)
    put_data(db, df, tablename)
end

function test(dbpath, tablename)
    db = SQLite.DB(dbpath)
    query = """
        SELECT *
        FROM $tablename;
    """
    df = get_data(db, query)
end

end
