use application::errors::UseCaseError;
use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;

pub struct ApiError(UseCaseError);

#[rustfmt::skip]
impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self.0 {
            UseCaseError::AccountIdExists => (
                StatusCode::CONFLICT, "Account ID already exists".to_string(),
            ),
            UseCaseError::PasswordMismatch => (
                StatusCode::BAD_REQUEST, "The entered passwords do not match".to_string(),
            ),
            UseCaseError::BadRequest(reason) => (StatusCode::BAD_REQUEST, reason),
            UseCaseError::Unauthorized => (StatusCode::UNAUTHORIZED, "Unauthorized".to_string()),
            UseCaseError::InvalidCredentials => {
                (StatusCode::UNAUTHORIZED, "Invalid credentials".to_string())
            }
            UseCaseError::Infrastructure(_) => (
                StatusCode::INTERNAL_SERVER_ERROR, "An internal server error occurred".to_string(),
            ),
        };

        let body = Json(json!({ "error": error_message }));
        (status, body).into_response()
    }
}

impl From<UseCaseError> for ApiError {
    fn from(error: UseCaseError) -> Self {
        Self(error)
    }
}
