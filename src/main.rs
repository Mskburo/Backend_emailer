pub mod email;

use dotenv::dotenv;
use email::emails::emailer_server::EmailerServer;
use email::Email;
use tonic::transport::Server;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let addr: std::net::SocketAddr = "[::1]:50051".parse()?;
    let email_service = Email::default();

    Server::builder()
        .add_service(EmailerServer::new(email_service))
        .serve(addr)
        .await?;

    Ok(())

}
