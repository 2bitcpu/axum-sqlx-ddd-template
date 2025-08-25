pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

#[cfg(feature = "sqlite")]
pub type DbPool = sqlx::SqlitePool;
#[cfg(feature = "sqlite")]
pub type DbExecutor = sqlx::SqliteConnection;
#[cfg(feature = "sqlite")]
pub type Db = sqlx::sqlite::Sqlite;

#[cfg(feature = "postgres")]
pub type DbPool = sqlx::PgPool;
#[cfg(feature = "postgres")]
pub type DbExecutor = sqlx::PgConnection;
#[cfg(feature = "postgres")]
pub type Db = sqlx::Postgres;
