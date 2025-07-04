use crate_a::A;
use crate_d::D;

#[tokio::main]
async fn main() {
    let a = A::new("main".to_string());
    let d = D::new("main".to_string());
    
    println!("{}", a.greet());
    println!("{}", d.greet());
    
    println!("App running successfully!");
}