use std::sync::Arc;

use crate::errors::UseCaseError;
use crate::model::todo::{TodoDto, CreateTodoRequest};
use domain::{UnitOfWorkProvider, model::todo::TodoEntity};

pub struct TodoUseCase {
    provider: Arc<dyn UnitOfWorkProvider + Send + Sync>,
}

impl TodoUseCase {
    pub fn new(provider: Arc<dyn UnitOfWorkProvider + Send + Sync>) -> Self {
        Self { provider }
    }

    pub async fn create(&self, dto: CreateTodoRequest) -> Result<TodoDto, UseCaseError> {
        let mut uow = self.provider.begin().await?;

        let entity = TodoEntity {
            id: 0,
            account: dto.account.clone(),
            due_date: dto.due_date,
            content: dto.content.clone(),
            complete: dto.complete,
        };

        let entity = uow.todo().insert(&entity).await?;

        uow.commit().await?;

        Ok(TodoDto {
            id: entity.id,
            account: entity.account,
            due_date: entity.due_date,
            content: entity.content,
            complete: entity.complete,
        })
    }

    pub async fn find(&self, id: i64) -> Result<Option<TodoDto>, UseCaseError> {
        let mut uow = self.provider.begin().await?;
        let entity = uow.todo().selectl(id).await?;
        uow.commit().await?;
        Ok(entity.map(|e| TodoDto {
            id: e.id,
            account: e.account,
            due_date: e.due_date,
            content: e.content,
            complete: e.complete,
        }))
    }
}
