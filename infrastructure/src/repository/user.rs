use async_trait::async_trait;
use common::types::{BoxError, DbExecutor};
use derive_new::new;
use domain::{interface::user::UserRepository, model::user::UserEntity};

#[derive(new, Debug)]
pub struct UserRepositoryImpl<'a> {
    executor: &'a mut DbExecutor,
}

#[async_trait]
impl<'a> UserRepository for UserRepositoryImpl<'a> {
    async fn insert(&mut self, entity: &UserEntity) -> Result<UserEntity, BoxError> {
        let rec = sqlx::query_as::<_, UserEntity>("INSERT INTO  (account,password) VALUES (?,?) RETURNING *")
            .bind(&entity.account)
            .bind(&entity.password)
            .fetch_one(&mut *self.executor)
            .await?;

        Ok(rec)
    }

    async fn select(&mut self, account: &str) -> Result<Option<UserEntity>, BoxError> {
        let rec = sqlx::query_as::<_, UserEntity>("SELECT * FROM  WHERE  account=?")
            .bind(&account)
            .fetch_optional(&mut *self.executor)
            .await?;

        Ok(rec)
    }
}
