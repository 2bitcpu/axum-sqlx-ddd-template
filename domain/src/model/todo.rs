use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Deserialize, Clone, Debug)]
pub struct TodoEntity {
    pub id: i64,
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}
