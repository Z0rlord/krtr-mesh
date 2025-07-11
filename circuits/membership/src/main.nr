// KRTR Anonymous Membership Circuit
// Proves membership in authorized group without revealing identity

use dep::std;

// Maximum depth for membership tree
global TREE_DEPTH: u32 = 20;

fn main(
    // Private inputs (not revealed)
    secret_key: Field,
    path_elements: [Field; TREE_DEPTH],
    path_indices: [Field; TREE_DEPTH],
    
    // Public inputs (revealed)
    group_root: pub Field,
    nullifier_hash: pub Field,
    signal_hash: pub Field
) {
    // 1. Verify membership in the group
    let leaf = std::hash::pedersen_hash([secret_key]);
    let computed_root = compute_merkle_root(leaf[0], path_elements, path_indices);
    assert(computed_root == group_root);
    
    // 2. Generate nullifier to prevent double-use
    let computed_nullifier = std::hash::pedersen_hash([secret_key, signal_hash]);
    assert(computed_nullifier[0] == nullifier_hash);
}

fn compute_merkle_root(
    leaf: Field,
    path_elements: [Field; TREE_DEPTH],
    path_indices: [Field; TREE_DEPTH]
) -> Field {
    let mut current = leaf;
    
    for i in 0..TREE_DEPTH {
        let path_element = path_elements[i];
        let is_right = path_indices[i];
        
        let left = if is_right == 1 { path_element } else { current };
        let right = if is_right == 1 { current } else { path_element };
        
        let hash_result = std::hash::pedersen_hash([left, right]);
        current = hash_result[0];
    }
    
    current
}
