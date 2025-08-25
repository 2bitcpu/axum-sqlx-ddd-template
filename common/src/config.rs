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
                issuer: env!("CARGO_PKG_NAME").to_string(),
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
