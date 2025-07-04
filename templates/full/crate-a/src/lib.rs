use crate_b::B;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct A {
    pub name: String,
    pub b: B,
}

impl A {
    pub fn new(name: String) -> Self {
        Self {
            name,
            b: B::new("from A".to_string()),
        }
    }
    
    pub fn greet(&self) -> String {
        format!("Hello from A: {}, {}", self.name, self.b.greet())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_a() {
        let a = A::new("test".to_string());
        assert!(a.greet().contains("Hello from A"));
    }
}