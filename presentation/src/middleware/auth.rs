use application::UseCaseModule;

use axum::RequestExt;
use axum::{
    extract::{FromRequestParts, Request, State},
    http::{StatusCode, request::Parts},
    middleware::Next,
    response::Response,
};
use axum_extra::{
    TypedHeader,
    headers::{Authorization, authorization::Bearer},
};
use std::sync::Arc;

#[derive(Clone)]
pub struct AuthUser {
    pub account: String,
}
#[derive(Clone)]
pub struct AuthOptionUser {
    pub account: Option<String>,
}

impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<Self>()
            .cloned()
            .ok_or(StatusCode::UNAUTHORIZED)
    }
}

pub async fn auth_guard(
    State(module): State<Arc<dyn UseCaseModule>>,
    mut request: Request,
    next: Next,
) -> axum::response::Result<Response> {
    let bearer = request
        .extract_parts::<TypedHeader<Authorization<Bearer>>>()
        .await
        .map_err(|_| StatusCode::UNAUTHORIZED)?;
    let token = bearer.token();

    let account = module
        .auth()
        .authenticate(token)
        .await
        .map_err(|_| StatusCode::UNAUTHORIZED)?;

    let auth_account = AuthUser { account };
    request.extensions_mut().insert(auth_account);

    Ok(next.run(request).await)
}

impl<S> FromRequestParts<S> for AuthOptionUser
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<Self>()
            .cloned()
            .ok_or(StatusCode::UNAUTHORIZED)
    }
}

pub async fn auth_option_guard(
    State(module): State<Arc<dyn UseCaseModule>>,
    mut request: Request,
    next: Next,
) -> Response {
    let mut auth_account = AuthOptionUser { account: None };

    if let Ok(bearer) = request
        .extract_parts::<TypedHeader<Authorization<Bearer>>>()
        .await
    {
        if let Ok(account) = module.auth().authenticate(bearer.token()).await {
            auth_account.account = Some(account);
        }
    }
    request.extensions_mut().insert(auth_account);
    next.run(request).await
}
