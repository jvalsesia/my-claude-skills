use std::net::SocketAddr;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use {{PROJECT_NAME_SNAKE}}_lib::{app, config::Config, db};

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
            format!("{}=debug,tower_http=debug", env!("CARGO_PKG_NAME")).into()
        }))
        .with(tracing_subscriber::fmt::layer())
        .init();

    dotenvy::dotenv().ok();

    let config = Config::from_env().expect("failed to load config");
    let pool = db::connect(&config.database_url).await.expect("failed to connect to database");

    db::migrate(&pool).await.expect("failed to run migrations");

    let router = app(pool, config.clone());
    let addr = SocketAddr::from(([0, 0, 0, 0], config.server_port));

    tracing::info!("listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, router).await.unwrap();
}
