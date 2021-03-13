module DOEVDBManager

using SQLite
using DataFrames

export get_data, put_data

get_data(db, query) = DBInterface.execute(db, query) |> DataFrame

put_data(db, df, tablename) = df |> SQLite.load!(db, tablename)


setup(dbpath, tablename) = SQLite.DB(dbpath)

function setup(dbpath, tablename, df)
    db = setup(dbpath, tablename)
    put_data(db, df, tablename)
    db
end

end
