use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Deserialize, Clone, Debug)]
pub struct MemberEntity {
    pub account: String,
    pub password: String,
}
