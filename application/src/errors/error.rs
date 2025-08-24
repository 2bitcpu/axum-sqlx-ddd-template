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
