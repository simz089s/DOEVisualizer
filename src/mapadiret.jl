module mapadiret

using SQLite

function __init__()
    SQLite.DB("../db.db") do conn
        ;
    end
end

end
