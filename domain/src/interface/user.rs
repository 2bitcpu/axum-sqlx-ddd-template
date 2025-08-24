use async_trait::async_trait;
use common::types::BoxError;

use crate::model::user::UserEntity;

#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn insert(&mut self, user: &UserEntity) -> Result<UserEntity, BoxError>;
    async fn select(&mut self, accunt: &str) -> Result<Option<UserEntity>, BoxError>;
}
