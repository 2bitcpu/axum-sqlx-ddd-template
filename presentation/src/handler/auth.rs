use axum::{Json, extract::State};
use std::sync::Arc;

use crate::errors::ApiError;
use application::UseCaseModule;
use application::model::auth::{SigninRequest, SigninResponse, SignupRequest, SignupResponse};

pub async fn signup(
    State(usecases): State<Arc<dyn UseCaseModule>>,
    Json(dto): Json<SignupRequest>,
) -> Result<Json<SignupResponse>, ApiError> {
    let res = usecases.auth().signup(dto).await?;
    Ok(Json(res))
}

pub async fn signin(
    State(usecases): State<Arc<dyn UseCaseModule>>,
    Json(dto): Json<SigninRequest>,
) -> Result<Json<SigninResponse>, ApiError> {
    let res = usecases.auth().signin(dto).await?;
    Ok(Json(res))
}
