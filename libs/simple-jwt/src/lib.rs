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
