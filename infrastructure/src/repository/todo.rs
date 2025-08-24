use async_trait::async_trait;
use common::types::{BoxError, DbExecutor};
use derive_new::new;
use domain::{interface::todo::TodoRepository, model::todo::TodoEntity};

#[derive(new, Debug)]
pub struct TodoRepositoryImpl<'a> {
    executor: &'a mut DbExecutor,
}

#[async_trait]
impl<'a> TodoRepository for TodoRepositoryImpl<'a> {
    async fn insert(&mut self, entity: &TodoEntity) -> Result<TodoEntity, BoxError> {
        let rec = sqlx::query_as::<_, TodoEntity>(
            "INSERT INTO todo (account,due_date,content,complete) VALUES (?,?,?,?) RETURNING *",
        )
        .bind(&entity.account)
        .bind(&entity.due_date)
        .bind(&entity.content)
        .bind(&entity.complete)
        .fetch_one(&mut *self.executor)
        .await?;

        Ok(rec)
    }

    async fn selectl(&mut self, id: i64) -> Result<Option<TodoEntity>, BoxError> {
        let rec = sqlx::query_as::<_, TodoEntity>("SELECT * FROM todo WHERE id = ?")
            .bind(&id)
            .fetch_optional(&mut *self.executor)
            .await?;

        Ok(rec)
    }
}
