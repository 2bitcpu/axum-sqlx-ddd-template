#[allow(unused_imports)]
use axum::{
    Router,
    http::{HeaderValue, Method},
    middleware::from_fn_with_state,
    routing::{delete, get, get_service, post, put},
};
use std::sync::Arc;
use tower_http::{cors::CorsLayer, services::ServeDir};

use crate::handler::{auth, todo};
use crate::middleware::auth::{auth_guard, auth_option_guard};
use application::UseCaseModule;

pub fn create(usecases: Arc<dyn UseCaseModule>) -> Router {
    let auth_router = Router::new()
        .route("/signup", post(auth::signup))
        .route("/signin", post(auth::signin));

    let manage_router = Router::new()
        .route("/todo", post(todo::create))
        .layer(from_fn_with_state(usecases.clone(), auth_guard));

    let public_router = Router::new()
        .route("/todo/{id}", get(todo::find))
        .layer(from_fn_with_state(usecases.clone(), auth_option_guard));

    let mut app = Router::new()
        .nest("/auth", auth_router)
        .nest("/manage", manage_router)
        .merge(public_router)
        .with_state(usecases);

    if !config::CONFIG.server.cors.is_empty() {
        let cors = CorsLayer::new()
            .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
            .allow_origin(
                config::CONFIG
                    .server
                    .cors
                    .iter()
                    .map(|s| s.parse::<HeaderValue>().unwrap())
                    .collect::<Vec<_>>(),
            );
        app = app.layer(cors);
    }

    app = Router::new().nest("/service", app);

    if let Some(dir) = config::CONFIG.server.static_dir.as_ref() {
        app.fallback(get_service(ServeDir::new(dir)))
    } else {
        app
    }
}
