using Microsoft.Data.Sqlite;

namespace Gyroball.Core.Storage;

/// <summary>
/// Minimal wrapper around Microsoft.Data.Sqlite — just enough for the session
/// store. Mirrors the macOS Database.swift. Not thread-safe; use from one thread.
/// </summary>
public sealed class Database : IDisposable
{
    private readonly SqliteConnection _conn;

    public Database(string path)
    {
        _conn = new SqliteConnection(new SqliteConnectionStringBuilder
        {
            DataSource = path,
            Mode = SqliteOpenMode.ReadWriteCreate
        }.ToString());
        _conn.Open();
    }

    public long LastInsertId
    {
        get
        {
            using var cmd = _conn.CreateCommand();
            cmd.CommandText = "SELECT last_insert_rowid()";
            return (long)(cmd.ExecuteScalar() ?? 0L);
        }
    }

    /// <summary>Runs a statement with positional parameters, invoking <paramref name="row"/> per result row.</summary>
    public void Run(string sql, IReadOnlyList<object>? bind = null, Action<SqliteDataReader>? row = null)
    {
        using var cmd = _conn.CreateCommand();
        cmd.CommandText = sql;
        if (bind is not null)
        {
            for (int i = 0; i < bind.Count; i++)
                cmd.Parameters.AddWithValue($"@p{i}", bind[i]);
            // Rewrite positional '?' into the named params we just added.
            cmd.CommandText = RewritePlaceholders(sql, bind.Count);
        }

        if (row is null)
        {
            cmd.ExecuteNonQuery();
            return;
        }

        using var reader = cmd.ExecuteReader();
        while (reader.Read()) row(reader);
    }

    private static string RewritePlaceholders(string sql, int count)
    {
        var sb = new System.Text.StringBuilder(sql.Length + count * 2);
        int idx = 0;
        foreach (char c in sql)
        {
            if (c == '?') sb.Append("@p").Append(idx++);
            else sb.Append(c);
        }
        return sb.ToString();
    }

    public void Dispose() => _conn.Dispose();
}
