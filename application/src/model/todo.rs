use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};


#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct CreateTodoRequest {
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TodoDto {
    pub id: i64,
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}
