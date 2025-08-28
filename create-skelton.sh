#!/bin/bash

if [[ "$1" == "-d" || "$1" == "--del" ]]; then
    find . -mindepth 1 -maxdepth 1 ! \( -name "*.md" -o -name "*.sql" -o -name "*.sh" -o -name "*.yaml" \) -exec rm -rf {} +
elif find . -mindepth 1 -maxdepth 1 ! \( -name "*.md" -o -name "*.sql" -o -name "*.sh" -o -name "*.yaml" \) | grep -q .; then
    echo "Project already exists."
    exit 1
fi

cargo new _tmp
cd _tmp
cargo add tokio --features macros,rt-multi-thread,signal --no-default-features
cargo add serde --features derive --no-default-features
cargo add serde_json --features std --no-default-features
cargo add chrono --features serde,now --no-default-features
cargo add async-trait --no-default-features
cargo add derive-new --no-default-features
cargo add axum --features macros
cargo add axum-extra --features typed-header --no-default-features
cargo add tower --features timeout --no-default-features
cargo add tower-http --features fs,cors --no-default-features
cargo add sqlx --features runtime-tokio-rustls,chrono,derive --no-default-features
cargo add jsonwebtoken --no-default-features
cargo add uuid --features v4,serde --no-default-features
cargo add argon2 --features alloc,password-hash,std --no-default-features
cargo add password-hash --features getrandom --no-default-features
cargo add serde_yaml --no-default-features
cargo add clap --features derive 
cargo add once_cell --features std --no-default-features
cargo add tracing --no-default-features
cargo add tracing-subscriber --no-default-features --features fmt,env-filter
cd ..

cat <<EOF > Cargo.toml
[workspace.package]
version = "0.1.0"
edition = "2024"

[workspace]
resolver = "2"
members = []

[workspace.dependencies]
EOF

sed '1,/\[dependencies\]/d' _tmp/Cargo.toml >> Cargo.toml
rm -rf _tmp

cargo new libs/async-argon2 --lib
cargo new libs/simple-jwt --lib
cargo new config --lib
cargo new common/sqlite --lib --name common
cargo new domain --lib
cargo new infrastructure --lib
cargo new application --lib
cargo new presentation --lib
cargo new web-api

find . \( -name ".git" -o -name ".gitignore" \) -exec rm -rf {} +

cat <<EOF >> .gitignore
target
Cargo.lock
.DS_Store
EOF

cat <<EOF >> Cargo.toml

async-argon2 = { path = "libs/async-argon2" }
simple-jwt = { path = "libs/simple-jwt" }
config = { path = "config" }
common = { path = "common/sqlite" }
domain = { path = "domain" }
infrastructure = { path = "infrastructure" }
application = { path = "application" }
presentation = { path = "presentation" }
# web-api = { path = "web-api" }

[profile.release]
opt-level = "z"
debug = false
lto = true
strip = true
codegen-units = 1
panic = "abort"
EOF

# ------------------------------------------------------------------------------
# libs/async-argon2
# ------------------------------------------------------------------------------
cat <<EOF >> libs/async-argon2/Cargo.toml
argon2.workspace = true
password-hash.workspace = true
tokio = { workspace = true, features = ["rt-multi-thread"], default-features = false }
EOF

cat <<EOF > libs/async-argon2/src/lib.rs
use argon2::{
    password_hash::{rand_core::OsRng, SaltString},
    Argon2, PasswordHash, PasswordHasher, PasswordVerifier,
};
use tokio::task;

pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

pub async fn hash(password: String) -> Result<String, BoxError> {
    task::spawn_blocking(move || {
        let salt = SaltString::generate(&mut OsRng);
        Ok(Argon2::default()
            .hash_password(password.as_bytes(), &salt)?
            .to_string())
    })
    .await?
}

pub async fn verify(password: String, hash: String) -> Result<bool, BoxError> {
    task::spawn_blocking(move || {
        let hash = PasswordHash::new(&hash)?;
        match Argon2::default().verify_password(password.as_bytes(), &hash) {
            Ok(()) => Ok(true),
            Err(password_hash::Error::Password) => Ok(false),
            Err(e) => Err(e.into()),
        }
    })
    .await?
}
EOF

# ------------------------------------------------------------------------------
# libs/simple-jwt
# ------------------------------------------------------------------------------
cat <<EOF >> libs/simple-jwt/Cargo.toml
chrono = { workspace = true, default-features = false, features = ["now"] }
jsonwebtoken.workspace = true
serde.workspace = true
uuid.workspace = true
EOF

cat <<EOF > libs/simple-jwt/src/lib.rs
use chrono::{DateTime, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::sync::LazyLock;

static JWT_SECRET: LazyLock<String> = LazyLock::new(|| uuid::Uuid::new_v4().to_string());

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Claims {
    pub sub: String, // subject (ユーザーの識別子)
    pub iss: String, // issuer (JWTの発行者)
    pub iat: i64,    // Issued At (発行日時)
    pub exp: i64,    // expiration time (トークンの有効期限)
    pub jti: String, // JWT ID (JWTの一意な識別子)
}

impl Claims {
    pub fn new(sub: &str, duration_seconds: i64) -> Self {
        let current_time: DateTime<Utc> = Utc::now();
        Self {
            sub: sub.to_string(),
            iss: exe_basename(),
            iat: current_time.timestamp(),
            exp: current_time.timestamp() + duration_seconds,
            jti: uuid::Uuid::new_v4().to_string(),
        }
    }
}

pub fn encode(claims: &Claims) -> Result<String, jsonwebtoken::errors::Error> {
    Ok(jsonwebtoken::encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(JWT_SECRET.to_string().as_bytes()),
    )?)
}

pub fn decode(token: &str) -> Result<Claims, jsonwebtoken::errors::Error> {
    let mut validation = Validation::default();
    validation.leeway = 30;
    validation.validate_exp = true;
    validation.set_issuer(&[exe_basename()]);
    let claims: Claims = jsonwebtoken::decode::<Claims>(
        &token,
        &DecodingKey::from_secret(JWT_SECRET.to_string().as_ref()),
        &validation,
    )?
    .claims;
    Ok(claims)
}

fn exe_basename() -> String {
    std::env::current_exe()
        .ok()
        .and_then(|path| path.file_stem().map(|s| s.to_string_lossy().to_string()))
        .unwrap_or_else(|| "unknown".to_string())
}
EOF

# ------------------------------------------------------------------------------
# config
# ------------------------------------------------------------------------------
cat <<EOF >> config/Cargo.toml
clap.workspace = true
once_cell.workspace = true
serde.workspace = true
serde_yaml.workspace = true
uuid.workspace = true
tracing-subscriber.workspace = true
EOF

cat <<EOF > config/src/config.rs
use clap::Parser;
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use tracing_subscriber::EnvFilter;
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub database: DatabaseConfig,
    pub server: ServerConfig,
    pub jwt: JwtConfig,
    pub log: LogConfig,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DatabaseConfig {
    pub dsn: String,
    pub migration: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ServerConfig {
    pub host: String,
    pub cors: Vec<String>,
    #[serde(rename = "static")]
    pub static_dir: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct JwtConfig {
    pub issuer: String,
    pub secret: String,
    pub expire: i64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct LogConfig {
    pub level: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            database: DatabaseConfig {
                dsn: "sqlite:data.db".to_string(),
                migration: None,
            },
            server: ServerConfig {
                host: "0.0.0.0:3000".to_string(),
                cors: vec![],
                static_dir: None,
            },
            jwt: JwtConfig {
                issuer: Config::exe_basename(),
                secret: Uuid::new_v4().to_string(),
                expire: 60 * 60 * 24,
            },
            log: LogConfig { level: None },
        }
    }
}

pub static CONFIG: Lazy<Config> = Lazy::new(|| {
    let mut cfg = Config::default();
    let exe_name = Config::exe_basename();
    let filename = format!("{exe_name}.config.yaml");

    let paths = vec![
        format!("/etc/{exe_name}/{filename}"),
        format!(
            "{}/{}",
            std::env::current_exe().unwrap().parent().unwrap().display(),
            filename
        ),
        filename.clone(),
    ];

    for path in paths {
        if Path::new(&path).exists() {
            if let Ok(content) = fs::read_to_string(&path) {
                if let Ok(file_cfg) = serde_yaml::from_str::<PartialConfig>(&content) {
                    cfg.merge(file_cfg);
                }
            }
        }
    }

    cfg.validate();
    let cli = Cli::parse();
    cfg.apply_cli(&cli);

    cfg
});

#[derive(Debug, Deserialize)]
struct PartialConfig {
    database: Option<PartialDatabaseConfig>,
    server: Option<PartialServerConfig>,
    jwt: Option<PartialJwtConfig>,
    log: Option<PartialLogConfig>,
}

#[derive(Debug, Deserialize)]
struct PartialDatabaseConfig {
    dsn: Option<String>,
    migration: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PartialServerConfig {
    host: Option<String>,
    cors: Option<Vec<String>>,
    #[serde(rename = "static")]
    static_dir: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PartialJwtConfig {
    issuer: Option<String>,
    secret: Option<String>,
    expire: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct PartialLogConfig {
    level: Option<String>,
}

impl Config {
    pub fn validate(&mut self) {
        if let Some(ref level) = self.log.level {
            if EnvFilter::try_new(level).is_err() {
                eprintln!(
                    "Invalid log filter expression: '{}'. Logging will be disabled.",
                    level
                );
                self.log.level = None;
            }
        }

        if let Some(ref dir) = self.server.static_dir {
            if !Path::new(dir).is_dir() {
                eprintln!(
                    "Static directory '{}' does not exist. Static serving will be disabled.",
                    dir
                );
                self.server.static_dir = None;
            }
        }

        if let Some(ref file) = self.database.migration {
            if !Path::new(file).is_file() {
                eprintln!(
                    "Migration file '{}' does not exist. Database migration will be disabled.",
                    file
                );
                self.database.migration = None;
            }
        }
    }

    fn merge(&mut self, p: PartialConfig) {
        if let Some(db) = p.database {
            if let Some(dsn) = db.dsn {
                self.database.dsn = dsn;
            }
            if let Some(migration) = db.migration {
                self.database.migration = Some(migration);
            }
        }
        if let Some(server) = p.server {
            if let Some(host) = server.host {
                self.server.host = host;
            }
            if let Some(cors) = server.cors {
                self.server.cors = cors;
            }
            if let Some(static_dir) = server.static_dir {
                self.server.static_dir = Some(static_dir);
            }
        }
        if let Some(jwt) = p.jwt {
            if let Some(issuer) = jwt.issuer {
                self.jwt.issuer = issuer;
            }
            if let Some(secret) = jwt.secret {
                self.jwt.secret = secret;
            }
            if let Some(expire) = jwt.expire {
                self.jwt.expire = expire;
            }
        }
        if let Some(log) = p.log {
            if let Some(level) = log.level {
                self.log.level = Some(level);
            }
        }
    }

    fn apply_cli(&mut self, cli: &Cli) {
        if let Some(db) = &cli.dsn {
            self.database.dsn = db.clone();
        }
        if cli.no_migration {
            self.database.migration = None;
        } else if let Some(file) = &cli.migration {
            if let Some(file_str) = file.to_str() {
                self.database.migration = Some(file_str.to_string());
            } else {
                eprintln!("Error: Invalid path string.");
            }
        }
        if let Some(host) = &cli.host {
            self.server.host = host.clone();
        }
        if cli.no_cors {
            self.server.cors.clear();
        } else if let Some(cors) = &cli.cors {
            self.server.cors = cors.clone();
        }
        if cli.no_static {
            self.server.static_dir = None;
        } else if let Some(dir) = &cli.static_dir {
            if let Some(dir_str) = dir.to_str() {
                self.server.static_dir = Some(dir_str.to_string());
            } else {
                eprintln!("Error: Invalid path string.");
            }
        }
        if let Some(issuer) = &cli.jwt_issuer {
            self.jwt.issuer = issuer.clone();
        }
        if let Some(secret) = &cli.jwt_secret {
            self.jwt.secret = secret.clone();
        }
        if let Some(exp) = cli.jwt_expire {
            self.jwt.expire = exp;
        }
        if cli.no_log {
            self.log.level = None;
        } else if let Some(level) = &cli.log_level {
            self.log.level = Some(level.clone());
        }
    }

    fn exe_basename() -> String {
        std::env::current_exe()
            .ok()
            .and_then(|path| path.file_stem().map(|s| s.to_string_lossy().to_string()))
            .unwrap_or_else(|| "unknown".to_string())
    }
}

#[derive(Parser, Debug)]
#[command(author, version, about)]
pub struct Cli {
    #[arg(long)]
    pub dsn: Option<String>,
    #[arg(long)]
    pub migration: Option<PathBuf>,
    #[arg(long)]
    pub no_migration: bool,

    #[arg(long)]
    pub host: Option<String>,
    #[arg(long)]
    pub cors: Option<Vec<String>>,
    #[arg(long)]
    pub no_cors: bool,

    #[arg(long)]
    pub static_dir: Option<PathBuf>,
    #[arg(long)]
    pub no_static: bool,

    #[arg(long)]
    pub jwt_issuer: Option<String>,
    #[arg(long)]
    pub jwt_secret: Option<String>,
    #[arg(long)]
    pub jwt_expire: Option<i64>,

    #[arg(long)]
    pub log_level: Option<String>,
    #[arg(long)]
    pub no_log: bool,
}
EOF

cat <<EOF > config/src/lib.rs
mod config;
pub use config::CONFIG;
EOF


# ------------------------------------------------------------------------------
# common
# ------------------------------------------------------------------------------
cat <<EOF >> common/sqlite/Cargo.toml
serde.workspace = true
sqlx = { workspace = true, features = ["sqlite"] }
tokio = { workspace = true, features = ["fs"], default-features = false }

config.workspace = true

EOF

cd common/sqlite
cargo add libsqlite3-sys@^0.30.1 --optional --no-default-features
cd ../../

cat <<EOF > common/sqlite/src/types.rs
pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

pub type DbPool = sqlx::SqlitePool;
pub type DbExecutor = sqlx::SqliteConnection;
pub type Db = sqlx::sqlite::Sqlite;
EOF

cat <<EOF > common/sqlite/src/setup.rs
use crate::types::{BoxError, DbPool};

use sqlx::Executor;
use std::str::FromStr;

use sqlx::sqlite::SqliteConnectOptions;

pub async fn init_db(dsn: &str) -> Result<DbPool, BoxError> {
    let options = SqliteConnectOptions::from_str(dsn)?.create_if_missing(true);
    let pool = DbPool::connect_with(options).await?;

    if let Some(file) = &config::CONFIG.database.migration {
        if let Ok(ddl) = tokio::fs::read_to_string(file).await {
            for stmt in ddl.split(';') {
                let stmt = stmt.trim();
                if !stmt.is_empty() {
                    pool.execute(stmt).await?;
                }
            }
        }
    }
    Ok(pool)
}
EOF

cat <<EOF > common/sqlite/src/lib.rs
pub mod setup;
pub mod types;
EOF

# ------------------------------------------------------------------------------
# domain
# ------------------------------------------------------------------------------
cat <<EOF >> domain/Cargo.toml
sqlx.workspace = true
serde.workspace = true
chrono.workspace = true
async-trait.workspace = true
tracing-subscriber.workspace = true

common.workspace = true
EOF

mkdir -p domain/src/model

cat <<EOF > domain/src/model/todo.rs
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Deserialize, Clone, Debug)]
pub struct TodoEntity {
    pub id: i64,
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}
EOF

cat <<EOF > domain/src/model/member.rs
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(FromRow, Serialize, Deserialize, Clone, Debug)]
pub struct MemberEntity {
    pub account: String,
    pub password: String,
}
EOF

cat <<EOF > domain/src/model/mod.rs
pub mod todo;
pub mod member;
EOF

mkdir -p domain/src/interface

cat <<EOF > domain/src/interface/todo.rs
use async_trait::async_trait;
use common::types::BoxError;

use crate::model::todo::TodoEntity;

#[async_trait]
pub trait TodoRepository: Send + Sync {
    async fn insert(&mut self, entity: &TodoEntity) -> Result<TodoEntity, BoxError>;
    async fn selectl(&mut self, id: i64) -> Result<Option<TodoEntity>, BoxError>;
}
EOF

cat <<EOF > domain/src/interface/member.rs
use async_trait::async_trait;
use common::types::BoxError;

use crate::model::member::MemberEntity;

#[async_trait]
pub trait MemberRepository: Send + Sync {
    async fn insert(&mut self, member: &MemberEntity) -> Result<MemberEntity, BoxError>;
    async fn select(&mut self, accunt: &str) -> Result<Option<MemberEntity>, BoxError>;
}
EOF


cat <<EOF > domain/src/interface/mod.rs
pub mod todo;
pub mod member;
EOF

cat <<EOF > domain/src/uow.rs
use async_trait::async_trait;

use crate::interface::todo::TodoRepository;
use crate::interface::member::MemberRepository;
use common::types::BoxError;

#[async_trait]
pub trait UnitOfWork: Send {
    async fn commit(self: Box<Self>) -> Result<(), BoxError>;
    async fn rollback(self: Box<Self>) -> Result<(), BoxError>;

    fn todo<'s>(&'s mut self) -> Box<dyn TodoRepository + 's>;
    fn member<'s>(&'s mut self) -> Box<dyn MemberRepository + 's>;
}

#[async_trait]
pub trait UnitOfWorkProvider: Send + Sync {
    async fn begin(&self) -> Result<Box<dyn UnitOfWork + '_>, BoxError>;
}
EOF

cat <<EOF > domain/src/lib.rs
pub mod model;
pub mod interface;

mod uow;
pub use uow::{UnitOfWork, UnitOfWorkProvider};
EOF

# ------------------------------------------------------------------------------
# infrastructure
# ------------------------------------------------------------------------------
cat <<EOF >> infrastructure/Cargo.toml
sqlx.workspace = true
async-trait.workspace = true
derive-new.workspace = true

common.workspace = true
domain.workspace = true
EOF

mkdir -p infrastructure/src/repository

cat <<EOF > infrastructure/src/repository/todo.rs
use async_trait::async_trait;
use common::types::{BoxError, DbExecutor};
use derive_new::new;
use domain::{interface::todo::TodoRepository, model::todo::TodoEntity};

#[derive(new, Debug)]
pub struct TodoRepositoryImpl<'a> {
    executor: &'a mut DbExecutor,
}

#[async_trait]
impl<'a> TodoRepository for TodoRepositoryImpl<'a> {
    async fn insert(&mut self, entity: &TodoEntity) -> Result<TodoEntity, BoxError> {
        let rec = sqlx::query_as::<_, TodoEntity>(
            "INSERT INTO todo (account,due_date,content,complete) VALUES (\$1,\$2,\$3,\$4) RETURNING *",
        )
        .bind(&entity.account)
        .bind(&entity.due_date)
        .bind(&entity.content)
        .bind(&entity.complete)
        .fetch_one(&mut *self.executor)
        .await?;

        Ok(rec)
    }

    async fn selectl(&mut self, id: i64) -> Result<Option<TodoEntity>, BoxError> {
        let rec = sqlx::query_as::<_, TodoEntity>("SELECT * FROM todo WHERE id=\$1")
            .bind(&id)
            .fetch_optional(&mut *self.executor)
            .await?;

        Ok(rec)
    }
}
EOF

cat <<EOF > infrastructure/src/repository/member.rs
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
        let rec = sqlx::query_as::<_, MemberEntity>("INSERT INTO member (account,password) VALUES (\$1,\$2) RETURNING *")
            .bind(&entity.account)
            .bind(&entity.password)
            .fetch_one(&mut *self.executor)
            .await?;

        Ok(rec)
    }

    async fn select(&mut self, account: &str) -> Result<Option<MemberEntity>, BoxError> {
        let rec = sqlx::query_as::<_, MemberEntity>("SELECT * FROM member WHERE account=\$1")
            .bind(&account)
            .fetch_optional(&mut *self.executor)
            .await?;

        Ok(rec)
    }
}
EOF

cat <<EOF > infrastructure/src/repository/mod.rs
pub mod todo;
pub mod member;
EOF

cat <<EOF > infrastructure/src/uow.rs
use async_trait::async_trait;

use common::types::{BoxError, Db, DbPool};
use domain::{
    UnitOfWork, UnitOfWorkProvider, interface::todo::TodoRepository,
    interface::member::MemberRepository,
};

use crate::repository::{todo::TodoRepositoryImpl, member::MemberRepositoryImpl};

pub struct UnitOfWorkImpl<'a> {
    tx: sqlx::Transaction<'a, Db>,
}

#[async_trait]
impl<'a> UnitOfWork for UnitOfWorkImpl<'a> {
    async fn commit(self: Box<Self>) -> Result<(), BoxError> {
        self.tx.commit().await?;
        Ok(())
    }
    async fn rollback(self: Box<Self>) -> Result<(), BoxError> {
        self.tx.rollback().await?;
        Ok(())
    }

    fn todo<'s>(&'s mut self) -> Box<dyn TodoRepository + 's> {
        Box::new(TodoRepositoryImpl::new(&mut self.tx))
    }
    fn member<'s>(&'s mut self) -> Box<dyn MemberRepository + 's> {
        Box::new(MemberRepositoryImpl::new(&mut self.tx))
    }
}

pub struct UnitOfWorkProviderImpl {
    pool: DbPool,
}

impl UnitOfWorkProviderImpl {
    pub fn new(pool: DbPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl UnitOfWorkProvider for UnitOfWorkProviderImpl {
    async fn begin(&self) -> Result<Box<dyn UnitOfWork + '_>, BoxError> {
        let tx = self.pool.begin().await?;
        Ok(Box::new(UnitOfWorkImpl { tx }))
    }
}
EOF

cat <<EOF > infrastructure/src/lib.rs
pub mod repository;

mod uow;
pub use uow::{UnitOfWorkImpl, UnitOfWorkProviderImpl};
EOF

# ------------------------------------------------------------------------------
# application
# ------------------------------------------------------------------------------
cat <<EOF >> application/Cargo.toml
serde.workspace = true
derive-new.workspace = true
chrono.workspace = true
async-trait.workspace = true

config.workspace = true
common.workspace = true
domain.workspace = true
simple-jwt.workspace = true
async-argon2.workspace = true
EOF

mkdir -p application/src/errors

cat <<EOF > application/src/errors/error.rs
use common::types::BoxError;
use std::{error::Error, fmt};

#[derive(Debug)]
pub enum UseCaseError {
    AccountIdExists,
    PasswordMismatch,
    InvalidCredentials,
    BadRequest(String),
    Unauthorized,
    Infrastructure(BoxError),
}

impl fmt::Display for UseCaseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            UseCaseError::AccountIdExists => write!(f, "Account ID already exists"),
            UseCaseError::PasswordMismatch => write!(f, "Passwords do not match"),
            UseCaseError::InvalidCredentials => write!(f, "Invalid account ID or password"),
            UseCaseError::BadRequest(reason) => write!(f, "Bad request: {}", reason),
            UseCaseError::Unauthorized => write!(f, "Un Authorized"),
            UseCaseError::Infrastructure(e) => {
                write!(f, "An unexpected infrastructure error occurred: {}", e)
            }
        }
    }
}

impl Error for UseCaseError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            UseCaseError::Infrastructure(e) => Some(e.as_ref()),
            _ => None,
        }
    }
}

impl From<BoxError> for UseCaseError {
    fn from(e: BoxError) -> Self {
        UseCaseError::Infrastructure(e)
    }
}
EOF

cat <<EOF > application/src/errors/mod.rs
mod error;
pub use error::UseCaseError;
EOF

mkdir -p application/src/model

cat <<EOF > application/src/model/auth.rs
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SignupRequest {
    pub account: String,
    pub password: String,
    pub confirmed_password: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SignupResponse {
    pub account: String,
}

#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SigninRequest {
    pub account: String,
    pub password: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SigninResponse {
    pub token: String,
}
EOF

cat <<EOF > application/src/model/todo.rs
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};


#[derive(Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct CreateTodoRequest {
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct TodoDto {
    pub id: i64,
    pub account: String,
    pub due_date: DateTime<Utc>,
    pub content: String,
    pub complete: bool,
}
EOF

cat <<EOF > application/src/model/mod.rs
pub mod auth;
pub mod todo;
EOF

mkdir -p application/src/usecase

cat <<EOF > application/src/usecase/auth.rs
use std::sync::Arc;

use crate::errors::UseCaseError;
use crate::model::auth::{SignupRequest, SignupResponse, SigninRequest, SigninResponse};
use domain::{UnitOfWorkProvider, model::member::MemberEntity};

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
        if uow.member().select(&dto.account).await?.is_some() {
            return Err(UseCaseError::AccountIdExists);
        }
        
        let hash_password = async_argon2::hash(dto.password).await?;
        let entity = MemberEntity {
            account: dto.account.clone(),
            password: hash_password,
        };

        let entity = uow.member().insert(&entity).await?;
        uow.commit().await?;

        Ok(SignupResponse {
            account: entity.account,
        })
    }

    pub async fn signin(&self, dto: SigninRequest) -> Result<SigninResponse, UseCaseError> {
        let mut uow = self.provider.begin().await?;

        let member = uow.member().select(&dto.account).await?;
        let member = match member {
            Some(u) => u,
            None => return Err(UseCaseError::Unauthorized),
        };

        if !async_argon2::verify(dto.password, member.password).await? {
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

        let member = match uow.member().select(&claims.sub).await? {
            Some(u) => u,
            None => return Err(UseCaseError::Unauthorized),
        };
        Ok(member.account.clone())
    }
}
EOF

cat <<EOF > application/src/usecase/todo.rs
use std::sync::Arc;

use crate::errors::UseCaseError;
use crate::model::todo::{TodoDto, CreateTodoRequest};
use domain::{UnitOfWorkProvider, model::todo::TodoEntity};

pub struct TodoUseCase {
    provider: Arc<dyn UnitOfWorkProvider + Send + Sync>,
}

impl TodoUseCase {
    pub fn new(provider: Arc<dyn UnitOfWorkProvider + Send + Sync>) -> Self {
        Self { provider }
    }

    pub async fn create(&self, dto: CreateTodoRequest) -> Result<TodoDto, UseCaseError> {
        let mut uow = self.provider.begin().await?;

        let entity = TodoEntity {
            id: 0,
            account: dto.account.clone(),
            due_date: dto.due_date,
            content: dto.content.clone(),
            complete: dto.complete,
        };

        let entity = uow.todo().insert(&entity).await?;

        uow.commit().await?;

        Ok(TodoDto {
            id: entity.id,
            account: entity.account,
            due_date: entity.due_date,
            content: entity.content,
            complete: entity.complete,
        })
    }

    pub async fn find(&self, id: i64) -> Result<Option<TodoDto>, UseCaseError> {
        let mut uow = self.provider.begin().await?;
        let entity = uow.todo().selectl(id).await?;
        uow.commit().await?;
        Ok(entity.map(|e| TodoDto {
            id: e.id,
            account: e.account,
            due_date: e.due_date,
            content: e.content,
            complete: e.complete,
        }))
    }
}
EOF

cat <<EOF > application/src/usecase/mod.rs
pub mod auth;
pub mod todo;
EOF

cat <<EOF > application/src/module.rs
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
EOF

cat <<EOF > application/src/lib.rs
pub mod errors;
pub mod model;
pub mod usecase;

mod module;
pub use module::{UseCaseModule, UseCaseModuleImpl};
EOF

# ------------------------------------------------------------------------------
# presentation
# ------------------------------------------------------------------------------
cat <<EOF >> presentation/Cargo.toml
axum.workspace = true
axum-extra.workspace = true
serde.workspace = true
serde_json.workspace = true
tower-http.workspace = true

config.workspace = true
common.workspace = true
application.workspace = true
EOF

mkdir -p presentation/src/errors

cat <<EOF > presentation/src/errors/error.rs
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
EOF

cat <<EOF > presentation/src/errors/mod.rs
mod error;
pub use error::ApiError;
EOF

mkdir -p presentation/src/middleware

cat <<EOF > presentation/src/middleware/auth.rs
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
pub struct AuthMember {
    pub account: String,
}
#[derive(Clone)]
pub struct AuthOptionMember {
    pub account: Option<String>,
}

impl<S> FromRequestParts<S> for AuthMember
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

    let auth_account = AuthMember { account };
    request.extensions_mut().insert(auth_account);

    Ok(next.run(request).await)
}

impl<S> FromRequestParts<S> for AuthOptionMember
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
    let mut auth_account = AuthOptionMember { account: None };

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
EOF

cat <<EOF > presentation/src/middleware/mod.rs
pub mod auth;
EOF

mkdir -p presentation/src/handler

cat <<EOF > presentation/src/handler/auth.rs
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
EOF

cat <<EOF > presentation/src/handler/todo.rs
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
EOF

cat <<EOF > presentation/src/handler/mod.rs
pub mod auth;
pub mod todo;
EOF

cat <<EOF > presentation/src/router.rs
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
EOF

cat <<EOF > presentation/src/lib.rs
pub mod errors;
pub mod middleware;
pub mod handler;
pub mod router;
EOF

# ------------------------------------------------------------------------------
# web-api
# ------------------------------------------------------------------------------
cat <<EOF >> web-api/Cargo.toml
config.workspace = true
common.workspace = true
presentation.workspace = true
application.workspace = true
infrastructure.workspace = true
tracing.workspace = true
tracing-subscriber.workspace = true

axum.workspace = true
tokio.workspace = true
EOF

cat <<EOF > web-api/src/main.rs
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
EOF

mkdir html

cat <<EOF > html/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
</head>
<body> This is static html </body>
</html>
EOF

mkdir -p common/postgres

cp -r common/sqlite/* common/postgres/

cat <<EOF > common/postgres/Cargo.toml
[package]
name = "common"
version.workspace = true
edition.workspace = true

[dependencies]
serde.workspace = true
sqlx = { workspace = true, features = ["postgres"] }
tokio = { workspace = true, features = ["fs"], default-features = false }

config.workspace = true
EOF

cat <<EOF > common/postgres/src/setup.rs
use crate::types::{BoxError, DbPool};

use sqlx::Executor;
use std::str::FromStr;

use sqlx::postgres::PgConnectOptions;

pub async fn init_db(dsn: &str) -> Result<DbPool, BoxError> {
    let options = PgConnectOptions::from_str(dsn)?;
    let pool = DbPool::connect_with(options).await?;

    if let Some(file) = &config::CONFIG.database.migration {
        if let Ok(ddl) = tokio::fs::read_to_string(file).await {
            for stmt in ddl.split(';') {
                let stmt = stmt.trim();
                if !stmt.is_empty() {
                    pool.execute(stmt).await?;
                }
            }
        }
    }
    Ok(pool)
}
EOF

cat <<EOF > common/postgres/src/types.rs
pub type BoxError = Box<dyn std::error::Error + Send + Sync>;

pub type DbPool = sqlx::PgPool;
pub type DbExecutor = sqlx::PgConnection;
pub type Db = sqlx::postgres::Postgres;
EOF
