use async_trait::async_trait;
use std::sync::Arc;

use crate::usecase::{auth::AuthUseCase, todo::TodoUseCase};
use domain::UnitOfWorkProvider;

#[async_trait]
pub trait UseCaseModule: Send + Sync {
    fn auth(&self) -> Arc<AuthUseCase>;
    fn todo(&self) -> Arc<TodoUseCase>;
}

#[derive(Clone)]
pub struct UseCaseModuleImpl {
    auth: Arc<AuthUseCase>,
    todo: Arc<TodoUseCase>,
}

impl UseCaseModuleImpl {
    pub fn new(provider: Arc<dyn UnitOfWorkProvider + Send + Sync>) -> Self {
        let auth = Arc::new(AuthUseCase::new(provider.clone()));
        let todo = Arc::new(TodoUseCase::new(provider));
        Self { auth, todo }
    }
}

impl UseCaseModule for UseCaseModuleImpl {
    fn auth(&self) -> Arc<AuthUseCase> {
        self.auth.clone()
    }
    fn todo(&self) -> Arc<TodoUseCase> {
        self.todo.clone()
    }
}
