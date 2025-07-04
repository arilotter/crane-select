use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Greeting {
    pub message: String,
}

pub fn greet(name: &str) -> String {
    let greeting = Greeting {
        message: format!("Hello, {}!", name),
    };
    greeting.message
}