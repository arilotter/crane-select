use crate_c::C;
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct B {
    pub name: String,
    pub c: C,
}

impl B {
    pub fn new(name: String) -> Self {
        Self {
            name,
            c: C::new("from B".to_string()),
        }
    }
    
    pub fn greet(&self) -> String {
        format!("Hello from B: {}, {}", self.name, self.c.greet())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_b() {
        let b = B::new("test".to_string());
        assert!(b.greet().contains("Hello from B"));
    }
}// change
