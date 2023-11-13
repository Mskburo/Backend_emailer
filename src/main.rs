pub mod email;

use dotenv::dotenv;
use email::emails::emailer_server::EmailerServer;
use email::Email;
use tonic::transport::Server;
use tracing::Level;
use tracing_subscriber::FmtSubscriber;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::TRACE)
        .finish();
    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");
    let addr: std::net::SocketAddr = "0.0.0.0:50051".parse()?;
    let email_service = Email::default();

    Server::builder()
        .accept_http1(true)
        .add_service(EmailerServer::new(email_service))
        .serve(addr)
        .await?;

    Ok(())
}
