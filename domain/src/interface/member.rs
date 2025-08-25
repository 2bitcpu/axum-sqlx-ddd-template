use async_trait::async_trait;
use common::types::BoxError;

use crate::model::member::MemberEntity;

#[async_trait]
pub trait MemberRepository: Send + Sync {
    async fn insert(&mut self, user: &MemberEntity) -> Result<MemberEntity, BoxError>;
    async fn select(&mut self, accunt: &str) -> Result<Option<MemberEntity>, BoxError>;
}
