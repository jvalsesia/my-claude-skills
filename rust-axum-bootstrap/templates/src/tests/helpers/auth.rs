use uuid::Uuid;

use crate::middleware::auth::create_token;

pub fn test_token(user_id: Uuid, email: &str, secret: &str) -> String {
    create_token(user_id, email, secret, 24).expect("failed to create test token")
}

pub fn bearer(token: &str) -> String {
    format!("Bearer {}", token)
}
