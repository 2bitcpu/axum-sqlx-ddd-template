use axum::{Extension, Json, extract::Path, extract::State};
use std::sync::Arc;

use crate::errors::ApiError;
use crate::middleware::auth::{AuthOptionMember, AuthMember};
use application::UseCaseModule;
use application::model::todo::{CreateTodoRequest, TodoDto};

pub async fn create(
    State(usecases): State<Arc<dyn UseCaseModule>>,
    Extension(_guard): Extension<AuthMember>,
    Json(dto): Json<CreateTodoRequest>,
) -> Result<Json<TodoDto>, ApiError> {
    let res = usecases.todo().create(dto).await?;
    Ok(Json(res))
}

pub async fn find(
    State(usecases): State<Arc<dyn UseCaseModule>>,
    Extension(_guard): Extension<AuthOptionMember>,
    Path(id): Path<i64>,
) -> Result<Json<Option<TodoDto>>, ApiError> {
    let res = usecases.todo().find(id).await?;
    Ok(Json(res))
}
