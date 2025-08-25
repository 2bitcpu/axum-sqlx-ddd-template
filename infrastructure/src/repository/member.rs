use async_trait::async_trait;
use common::types::{BoxError, DbExecutor};
use derive_new::new;
use domain::{interface::member::MemberRepository, model::member::MemberEntity};

#[derive(new, Debug)]
pub struct MemberRepositoryImpl<'a> {
    executor: &'a mut DbExecutor,
}

#[async_trait]
impl<'a> MemberRepository for MemberRepositoryImpl<'a> {
    async fn insert(&mut self, entity: &MemberEntity) -> Result<MemberEntity, BoxError> {
        let rec = sqlx::query_as::<_, MemberEntity>("INSERT INTO member (account,password) VALUES (?,?) RETURNING *")
            .bind(&entity.account)
            .bind(&entity.password)
            .fetch_one(&mut *self.executor)
            .await?;

        Ok(rec)
    }

    async fn select(&mut self, account: &str) -> Result<Option<MemberEntity>, BoxError> {
        let rec = sqlx::query_as::<_, MemberEntity>("SELECT * FROM member WHERE  account=?")
            .bind(&account)
            .fetch_optional(&mut *self.executor)
            .await?;

        Ok(rec)
    }
}
