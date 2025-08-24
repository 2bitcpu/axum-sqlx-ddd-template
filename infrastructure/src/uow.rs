use async_trait::async_trait;

use common::types::{BoxError, Db, DbPool};
use domain::{
    UnitOfWork, UnitOfWorkProvider, interface::todo::TodoRepository,
    interface::user::UserRepository,
};

use crate::repository::{todo::TodoRepositoryImpl, user::UserRepositoryImpl};

pub struct UnitOfWorkImpl<'a> {
    tx: sqlx::Transaction<'a, Db>,
}

#[async_trait]
impl<'a> UnitOfWork for UnitOfWorkImpl<'a> {
    async fn commit(self: Box<Self>) -> Result<(), BoxError> {
        self.tx.commit().await?;
        Ok(())
    }
    async fn rollback(self: Box<Self>) -> Result<(), BoxError> {
        self.tx.rollback().await?;
        Ok(())
    }

    fn todo<'s>(&'s mut self) -> Box<dyn TodoRepository + 's> {
        Box::new(TodoRepositoryImpl::new(&mut self.tx))
    }
    fn user<'s>(&'s mut self) -> Box<dyn UserRepository + 's> {
        Box::new(UserRepositoryImpl::new(&mut self.tx))
    }
}

pub struct UnitOfWorkProviderImpl {
    pool: DbPool,
}

impl UnitOfWorkProviderImpl {
    pub fn new(pool: DbPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl UnitOfWorkProvider for UnitOfWorkProviderImpl {
    async fn begin(&self) -> Result<Box<dyn UnitOfWork + '_>, BoxError> {
        let tx = self.pool.begin().await?;
        Ok(Box::new(UnitOfWorkImpl { tx }))
    }
}
