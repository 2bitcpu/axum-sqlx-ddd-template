use crate::config;
use crate::types::{BoxError, DbPool};
use sqlx::sqlite::SqliteConnectOptions;
use std::str::FromStr;

pub async fn init_db(dsn: &str) -> Result<DbPool, BoxError> {
    let options = SqliteConnectOptions::from_str(dsn)?.create_if_missing(true);
    let pool = sqlx::SqlitePool::connect_with(options).await?;

    if let Some(file) = &config::CONFIG.database.migration {
        if let Ok(query) = tokio::fs::read_to_string(file).await {
            sqlx::query(&query).execute(&pool).await?;
        }
    }

    Ok(pool)
}
