use std::env;

#[derive(Clone, Debug)]
pub struct Config {
    pub server_port: u16,
    pub database_url: String,
    pub jwt_secret: String,
    pub jwt_expiry_hours: u64,
}

impl Config {
    pub fn from_env() -> Result<Self, String> {
        Ok(Self {
            server_port: env::var("SERVER_PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .map_err(|_| "SERVER_PORT must be a valid port number")?,
            database_url: env::var("DATABASE_URL")
                .map_err(|_| "DATABASE_URL must be set")?,
            jwt_secret: env::var("JWT_SECRET")
                .map_err(|_| "JWT_SECRET must be set")?,
            jwt_expiry_hours: env::var("JWT_EXPIRY_HOURS")
                .unwrap_or_else(|_| "24".to_string())
                .parse()
                .map_err(|_| "JWT_EXPIRY_HOURS must be a number")?,
        })
    }
}
