#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🔧 Fixing React Native component syntax issues...\n');

// Find all JS files in React Native that contain component syntax
const findCommand = `find node_modules/react-native/Libraries -name "*.js" -exec grep -l "component(" {} \\;`;
let filesToFix;

try {
  filesToFix = execSync(findCommand, { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(file => file.length > 0);
} catch (error) {
  console.error('Error finding files:', error.message);
  process.exit(1);
}

console.log(`Found ${filesToFix.length} files with component syntax issues:`);
filesToFix.forEach(file => console.log(`  - ${file}`));
console.log('');

let totalFixesApplied = 0;

// Patterns to fix
const patterns = [
  // Pattern 1: const Name: component(...) = React.forwardRef(...)
  {
    name: 'forwardRef component syntax',
    regex:
      /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(React\.forwardRef\()/gm,
    replacement: '$1 = $2',
  },

  // Pattern 2: export default (Component: component(...))
  {
    name: 'export default component syntax',
    regex: /^(\s*export\s+default\s+)\((\w+):\s*component\(\s*[^)]*\)\)/gm,
    replacement: '$1$2',
  },

  // Pattern 3: type Name = component(...)
  {
    name: 'type component syntax',
    regex: /^(\s*type\s+\w+)\s*=\s*component\(\s*[^)]*\)/gm,
    replacement: '$1 = React.ComponentType<any>',
  },

  // Pattern 4: const Name: component(...) = Platform.select(...)
  {
    name: 'Platform.select component syntax',
    regex:
      /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(Platform\.select\()/gm,
    replacement: '$1 = $2',
  },

  // Pattern 5: const Name: component(...) = React.memo(...)
  {
    name: 'React.memo component syntax',
    regex: /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(React\.memo\()/gm,
    replacement: '$1 = $2',
  },

  // Pattern 6: Simple component type annotations
  {
    name: 'simple component type',
    regex: /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*([^;]+);?$/gm,
    replacement: '$1 = $2;',
  },

  // Pattern 7: Double type assertions (as any as Type)
  {
    name: 'double type assertion',
    regex: /^(\s*export\s+default\s+\w+)\s+as\s+any\s+as\s+\w+;?$/gm,
    replacement: '$1;',
  },
];

// Process each file
filesToFix.forEach(filePath => {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let originalContent = content;
    let fileFixesApplied = 0;

    // Apply each pattern
    patterns.forEach(pattern => {
      const matches = content.match(pattern.regex);
      if (matches) {
        content = content.replace(pattern.regex, pattern.replacement);
        fileFixesApplied += matches.length;
        console.log(
          `  ✓ Fixed ${matches.length} ${
            pattern.name
          } issue(s) in ${path.basename(filePath)}`
        );
      }
    });

    // Write back if changes were made
    if (content !== originalContent) {
      fs.writeFileSync(filePath, content, 'utf8');
      totalFixesApplied += fileFixesApplied;
      console.log(`  📝 Updated ${filePath} (${fileFixesApplied} fixes)`);
    }
  } catch (error) {
    console.error(`❌ Error processing ${filePath}:`, error.message);
  }
});

console.log(
  `\n🎉 Completed! Applied ${totalFixesApplied} fixes across ${filesToFix.length} files.`
);

// Generate patch
console.log('\n📦 Generating patch file...');
try {
  execSync('npx patch-package react-native', { stdio: 'inherit' });
  console.log('✅ Patch file generated successfully!');
} catch (error) {
  console.error('❌ Error generating patch:', error.message);
}

console.log('\n🚀 You can now run "npx expo start" to test your app!');
