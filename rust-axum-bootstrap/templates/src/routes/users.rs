use axum::{
    extract::{Path, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use uuid::Uuid;
use validator::Validate;

use crate::{
    errors::{AppError, AppResult},
    middleware::AuthUser,
    models::user::{AuthResponse, CreateUserDto, LoginDto, UserResponse},
    AppState,
};

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/users/register", post(register))
        .route("/users/login", post(login))
        .route("/users/me", get(me))
        .route("/users/:id", get(get_user))
}

async fn register(
    State(state): State<AppState>,
    Json(dto): Json<CreateUserDto>,
) -> AppResult<(StatusCode, Json<UserResponse>)> {
    dto.validate().map_err(|e| AppError::BadRequest(e.to_string()))?;

    let existing = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1 AND deleted_at IS NULL)",
    )
    .bind(&dto.email)
    .fetch_one(&state.pool)
    .await?;

    if existing {
        return Err(AppError::Conflict("email already registered".to_string()));
    }

    let password_hash = bcrypt::hash(&dto.password, bcrypt::DEFAULT_COST)
        .map_err(|e| AppError::BadRequest(e.to_string()))?;

    let user = sqlx::query_as::<_, crate::models::User>(
        r#"
        INSERT INTO users (id, email, name, password_hash, role)
        VALUES ($1, $2, $3, $4, 'user')
        RETURNING *
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(&dto.email)
    .bind(&dto.name)
    .bind(&password_hash)
    .fetch_one(&state.pool)
    .await?;

    Ok((StatusCode::CREATED, Json(user.into())))
}

async fn login(
    State(state): State<AppState>,
    Json(dto): Json<LoginDto>,
) -> AppResult<Json<AuthResponse>> {
    dto.validate().map_err(|e| AppError::BadRequest(e.to_string()))?;

    let user = sqlx::query_as::<_, crate::models::User>(
        "SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL",
    )
    .bind(&dto.email)
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::Unauthorized)?;

    let valid = bcrypt::verify(&dto.password, &user.password_hash)
        .map_err(|_| AppError::Unauthorized)?;

    if !valid {
        return Err(AppError::Unauthorized);
    }

    let token = crate::middleware::auth::create_token(
        user.id,
        &user.email,
        &state.config.jwt_secret,
        state.config.jwt_expiry_hours,
    )
    .map_err(|e| AppError::BadRequest(e.to_string()))?;

    Ok(Json(AuthResponse {
        token,
        user: user.into(),
    }))
}

async fn me(
    auth: AuthUser,
    State(state): State<AppState>,
) -> AppResult<Json<UserResponse>> {
    let user = sqlx::query_as::<_, crate::models::User>(
        "SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(auth.user_id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;

    Ok(Json(user.into()))
}

async fn get_user(
    _auth: AuthUser,
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
) -> AppResult<Json<UserResponse>> {
    let user = sqlx::query_as::<_, crate::models::User>(
        "SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL",
    )
    .bind(id)
    .fetch_optional(&state.pool)
    .await?
    .ok_or(AppError::NotFound)?;

    Ok(Json(user.into()))
}
