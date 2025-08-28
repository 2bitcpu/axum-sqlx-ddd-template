use application::UseCaseModuleImpl;
use common::{setup::init_db, types::BoxError};
use infrastructure::UnitOfWorkProviderImpl;
use presentation::router;
use std::sync::Arc;
use tokio::net::TcpListener;
use tracing_subscriber::{EnvFilter, fmt};

#[tokio::main]
async fn main() -> Result<(), BoxError> {
    if let Some(ref level) = config::CONFIG.log.level {
        let filter = EnvFilter::new(level);
        fmt().with_env_filter(filter).init();
    }

    let pool = init_db(&config::CONFIG.database.dsn.clone()).await?;

    let usecases = Arc::new(UseCaseModuleImpl::new(Arc::new(
        UnitOfWorkProviderImpl::new(pool),
    )));

    let app = router::create(usecases);

    let address = &*config::CONFIG.server.host;
    let listener = TcpListener::bind(address).await?;
    tracing::info!("->> LISTENING on http://{}", address);
    tracing::info!("->> CORS allowed origins: {:?}", config::CONFIG.server.cors);
    #[rustfmt::skip]
    tracing::info!(
        "->> Static files served from: {}",
        config::CONFIG.server.static_dir.as_deref().unwrap_or("(none)"));

    axum::serve(listener, app.into_make_service())
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        tokio::signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}
