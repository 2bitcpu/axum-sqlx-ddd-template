use async_trait::async_trait;
use common::types::BoxError;

use crate::model::todo::TodoEntity;

#[async_trait]
pub trait TodoRepository: Send + Sync {
    async fn insert(&mut self, entity: &TodoEntity) -> Result<TodoEntity, BoxError>;
    async fn selectl(&mut self, id: i64) -> Result<Option<TodoEntity>, BoxError>;
}
