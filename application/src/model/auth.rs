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
