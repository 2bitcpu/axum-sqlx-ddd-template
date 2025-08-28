pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

pub type DbPool = sqlx::SqlitePool;
pub type DbExecutor = sqlx::SqliteConnection;
pub type Db = sqlx::sqlite::Sqlite;
