pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

pub type DbPool = sqlx::PgPool;
pub type DbExecutor = sqlx::PgConnection;
pub type Db = sqlx::postgres::Postgres;
