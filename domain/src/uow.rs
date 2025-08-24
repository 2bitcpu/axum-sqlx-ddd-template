use async_trait::async_trait;

use crate::interface::todo::TodoRepository;
use crate::interface::user::UserRepository;
use common::types::BoxError;

#[async_trait]
pub trait UnitOfWork: Send {
    async fn commit(self: Box<Self>) -> Result<(), BoxError>;
    async fn rollback(self: Box<Self>) -> Result<(), BoxError>;

    fn todo<'s>(&'s mut self) -> Box<dyn TodoRepository + 's>;
    fn user<'s>(&'s mut self) -> Box<dyn UserRepository + 's>;
}

#[async_trait]
pub trait UnitOfWorkProvider: Send + Sync {
    async fn begin(&self) -> Result<Box<dyn UnitOfWork + '_>, BoxError>;
}
