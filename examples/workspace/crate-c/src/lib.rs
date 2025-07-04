use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct C {
    pub name: String,
}

impl C {
    pub fn new(name: String) -> Self {
        Self { name }
    }
    
    pub fn greet(&self) -> String {
        format!("Hello from C: {}", self.name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_c() {
        let c = C::new("test".to_string());
        assert_eq!(c.greet(), "Hello from C: test");
    }
}// This SHOULD rebuild crate-a
// change
// change to crate-c
// Test change Fri Jul  4 02:34:13 PM EDT 2025
