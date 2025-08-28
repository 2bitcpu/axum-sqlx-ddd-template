use crate::types::{BoxError, DbPool};

use sqlx::Executor;
use std::str::FromStr;

use sqlx::sqlite::SqliteConnectOptions;

pub async fn init_db(dsn: &str) -> Result<DbPool, BoxError> {
    let options = SqliteConnectOptions::from_str(dsn)?.create_if_missing(true);
    let pool = DbPool::connect_with(options).await?;

    if let Some(file) = &config::CONFIG.database.migration {
        if let Ok(ddl) = tokio::fs::read_to_string(file).await {
            for stmt in ddl.split(';') {
                let stmt = stmt.trim();
                if !stmt.is_empty() {
                    pool.execute(stmt).await?;
                }
            }
        }
    }
    Ok(pool)
}
