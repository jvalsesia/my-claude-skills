// Integration tests for user routes.
// The #[sqlx::test] macro creates an isolated database per test and runs migrations automatically.
// No manual cleanup is needed — the database is dropped after each test.

use axum_test::TestServer;
use serde_json::json;
use sqlx::PgPool;

use crate::{
    app,
    config::Config,
    tests::helpers::{auth::bearer, db::create_test_user},
};

fn test_config() -> Config {
    dotenvy::dotenv().ok();
    Config::from_env().expect("test config requires .env or environment variables")
}

#[sqlx::test(migrations = "./migrations")]
async fn test_register_creates_user(pool: PgPool) {
    let server = TestServer::new(app(pool, test_config())).unwrap();

    let res = server
        .post("/users/register")
        .json(&json!({ "email": "test@example.com", "password": "password123" }))
        .await;

    res.assert_status_created();
    let body = res.json::<serde_json::Value>();
    assert_eq!(body["email"], "test@example.com");
    assert_eq!(body["role"], "user");
    assert!(body.get("password_hash").is_none());
}

#[sqlx::test(migrations = "./migrations")]
async fn test_register_duplicate_email_returns_conflict(pool: PgPool) {
    let server = TestServer::new(app(pool.clone(), test_config())).unwrap();

    create_test_user(&pool, "dup@example.com", "password123").await;

    let res = server
        .post("/users/register")
        .json(&json!({ "email": "dup@example.com", "password": "password123" }))
        .await;

    res.assert_status(axum::http::StatusCode::CONFLICT);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_login_returns_token(pool: PgPool) {
    let server = TestServer::new(app(pool.clone(), test_config())).unwrap();

    create_test_user(&pool, "login@example.com", "password123").await;

    let res = server
        .post("/users/login")
        .json(&json!({ "email": "login@example.com", "password": "password123" }))
        .await;

    res.assert_status_ok();
    let body = res.json::<serde_json::Value>();
    assert!(body["token"].is_string());
    assert_eq!(body["user"]["email"], "login@example.com");
}

#[sqlx::test(migrations = "./migrations")]
async fn test_login_wrong_password_returns_unauthorized(pool: PgPool) {
    let server = TestServer::new(app(pool.clone(), test_config())).unwrap();

    create_test_user(&pool, "auth@example.com", "correct-password").await;

    let res = server
        .post("/users/login")
        .json(&json!({ "email": "auth@example.com", "password": "wrong-password" }))
        .await;

    res.assert_status(axum::http::StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_me_requires_auth(pool: PgPool) {
    let server = TestServer::new(app(pool, test_config())).unwrap();

    let res = server.get("/users/me").await;
    res.assert_status(axum::http::StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn test_me_returns_current_user(pool: PgPool) {
    let config = test_config();
    let server = TestServer::new(app(pool.clone(), config.clone())).unwrap();

    let user = create_test_user(&pool, "me@example.com", "password123").await;
    let token = bearer(&crate::tests::helpers::auth::test_token(
        user.id,
        &user.email,
        &config.jwt_secret,
    ));

    let res = server
        .get("/users/me")
        .add_header("Authorization", token)
        .await;

    res.assert_status_ok();
    let body = res.json::<serde_json::Value>();
    assert_eq!(body["email"], "me@example.com");
}
