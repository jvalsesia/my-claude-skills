use sqlx::PgPool;
use uuid::Uuid;

use crate::models::User;

pub async fn create_test_user(pool: &PgPool, email: &str, password: &str) -> User {
    let password_hash = bcrypt::hash(password, 4).unwrap();

    sqlx::query_as::<_, User>(
        r#"
        INSERT INTO users (id, email, password_hash, role)
        VALUES ($1, $2, $3, 'user')
        RETURNING *
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(email)
    .bind(&password_hash)
    .fetch_one(pool)
    .await
    .expect("failed to create test user")
}

pub async fn create_test_admin(pool: &PgPool, email: &str, password: &str) -> User {
    let password_hash = bcrypt::hash(password, 4).unwrap();

    sqlx::query_as::<_, User>(
        r#"
        INSERT INTO users (id, email, password_hash, role)
        VALUES ($1, $2, $3, 'admin')
        RETURNING *
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(email)
    .bind(&password_hash)
    .fetch_one(pool)
    .await
    .expect("failed to create test admin")
}
