use lettre::{
    message::header::ContentType, transport::smtp::authentication::Credentials, Message,
    SmtpTransport, Transport,
};
use tonic::{Request, Response, Status};

use emails::{EmailRequest, EmailResponse};

use self::emails::emailer_server::Emailer;

pub mod emails {
    tonic::include_proto!("emails");
}

#[derive(Debug, Default)]
pub struct Email {}

#[tonic::async_trait]
impl Emailer for Email {
    async fn send_email(
        &self,
        request: Request<EmailRequest>,
    ) -> Result<Response<EmailResponse>, Status> {
        println!("Got a request: {:?}", request);

        let req = request.into_inner();
        match Email::send(req) {
            Ok(result) => return Ok(Response::new(result)),
            Err(e) => {
                let reply = EmailResponse {
                    successful: false,
                    message: format!("{:?}", e).into(),
                };

                Ok(Response::new(reply))
            }
        }
    }
}

impl Email {
    fn send(request: EmailRequest) -> Result<EmailResponse, lettre::transport::smtp::Error> {
        let template_name = request.teplate;
        let html_template = render_template(template_name.to_string()).unwrap();
        let email = Message::builder()
            .from("Msk Buro <info@mskburo.ru>".parse().unwrap())
            .to(format!("Hei <{}>", request.to_email).parse().unwrap())
            .subject("Чек об оплате")
            .header(ContentType::TEXT_HTML)
            .body(html_template)
            .unwrap();

        let sender_email = std::env::var("SENDER_EMAIL").expect("SENDER_EMAIL must be set");
        let sender_password = std::env::var("SENDER_PASSWORD").expect("DATABASE_URL must be set");

        let creds = Credentials::new(sender_email, sender_password);

        // Open a remote connection to gmail
        let mailer = SmtpTransport::relay("smtp.mail.ru")
            .unwrap()
            .credentials(creds)
            .build();

        // Send the email
        match mailer.send(&email) {
            Ok(_) => {
                return Ok(EmailResponse {
                    successful: true,
                    message: "email sent".to_owned(),
                })
            }
            Err(e) => return Err(e),
        };
    }
}

fn render_template(template_name: String) -> Result<String, handlebars::RenderError> {
    let mut handlebars = handlebars::Handlebars::new();
    handlebars.register_template_file(
        &template_name,
        &format!("./templates/{}.hbs", template_name),
    )?;
    handlebars.register_template_file("styles", "./templates/partials/styles.hbs")?;
    handlebars.register_template_file("base", "./templates/layouts/base.hbs")?;

    let data = serde_json::json!({ // TODO
        "first_name":"hi",
        "subject": template_name,
        "url": ""
    });

    let content_template = handlebars.render(&template_name, &data)?;

    Ok(content_template)
}
