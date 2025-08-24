use std::sync::Arc;

use crate::errors::UseCaseError;
use crate::model::auth::{SignupRequest, SignupResponse, SigninRequest, SigninResponse};
use domain::{UnitOfWorkProvider, model::user::UserEntity};
use common::config;

pub struct AuthUseCase {
    provider: Arc<dyn UnitOfWorkProvider + Send + Sync>,
}

impl AuthUseCase {
    pub fn new(provider: Arc<dyn UnitOfWorkProvider + Send + Sync>) -> Self {
        Self { provider }
    }

    pub async fn signup(&self, dto: SignupRequest) -> Result<SignupResponse, UseCaseError> {
        let mut uow = self.provider.begin().await?;

        if dto.password != dto.confirmed_password {
            return Err(UseCaseError::BadRequest(
                "Password confirmation does not match".to_string(),
            ));
        }
        if uow.user().select(&dto.account).await?.is_some() {
            return Err(UseCaseError::AccountIdExists);
        }
        
        let hash_password = async_argon2::hash(dto.password).await?;
        let entity = UserEntity {
            account: dto.account.clone(),
            password: hash_password,
        };

        let entity = uow.user().insert(&entity).await?;
        uow.commit().await?;

        Ok(SignupResponse {
            account: entity.account,
        })
    }

    pub async fn signin(&self, dto: SigninRequest) -> Result<SigninResponse, UseCaseError> {
        let mut uow = self.provider.begin().await?;

        let user = uow.user().select(&dto.account).await?;
        let user = match user {
            Some(u) => u,
            None => return Err(UseCaseError::Unauthorized),
        };

        if !async_argon2::verify(dto.password, user.password).await? {
            return Err(UseCaseError::Unauthorized);
        }

        let claims = simple_jwt::Claims::new(&dto.account, config::CONFIG.jwt.expire);
        let token = simple_jwt::encode(&claims).map_err(|e| UseCaseError::Infrastructure(Box::new(e)))?;

        Ok(SigninResponse { token })
    }

    pub async fn authenticate(&self, token: &str) -> Result<String, UseCaseError> {
        let claims = match simple_jwt::decode(token) {
            Ok(c) => c,
            Err(_) => return Err(UseCaseError::Unauthorized),
        };

        let mut uow = self.provider.begin().await?;

        let user = match uow.user().select(&claims.sub).await? {
            Some(u) => u,
            None => return Err(UseCaseError::Unauthorized),
        };
        Ok(user.account.clone())
    }
}
