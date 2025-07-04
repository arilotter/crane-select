use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct D {
    pub name: String,
}

impl D {
    pub fn new(name: String) -> Self {
        Self { name }
    }
    
    pub fn greet(&self) -> String {
        format!("Hello from D: {}", self.name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_d() {
        let d = D::new("test".to_string());
        assert_eq!(d.greet(), "Hello from D: test");
    }
}// This should NOT rebuild crate-a
// change
// change to crate-d
