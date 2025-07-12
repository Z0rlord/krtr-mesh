#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

console.log('🔧 Comprehensive React Native Syntax Fixer v2.0\n');

// More comprehensive patterns to fix React Native syntax issues
const syntaxPatterns = [
  // Flow component syntax patterns
  {
    name: 'component forwardRef syntax',
    regex:
      /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(React\.forwardRef\()/gm,
    replacement: '$1 = $2',
    description: 'Fix component(...) = React.forwardRef(...)',
  },

  {
    name: 'component export syntax',
    regex: /^(\s*export\s+default\s+)\((\w+):\s*component\(\s*[^)]*\)\)/gm,
    replacement: '$1$2',
    description: 'Fix export default (Component: component(...))',
  },

  {
    name: 'component type definition',
    regex: /^(\s*type\s+\w+)\s*=\s*component\(\s*[^)]*\)/gm,
    replacement: '$1 = React.ComponentType<any>',
    description: 'Fix type Name = component(...)',
  },

  {
    name: 'component Platform.select',
    regex:
      /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(Platform\.select\()/gm,
    replacement: '$1 = $2',
    description: 'Fix component(...) = Platform.select(...)',
  },

  {
    name: 'component React.memo',
    regex: /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*(React\.memo\()/gm,
    replacement: '$1 = $2',
    description: 'Fix component(...) = React.memo(...)',
  },

  // Type assertion patterns
  {
    name: 'double type assertion',
    regex: /^(\s*export\s+default\s+\w+)\s+as\s+any\s+as\s+\w+;?$/gm,
    replacement: '$1;',
    description: 'Fix export default Name as any as Type',
  },

  {
    name: 'Flow type assertion in object',
    regex: /(\{[^}]*?)\s+as\s+\$FlowFixMe(\s*[,}])/g,
    replacement: '$1$2',
    description: 'Fix {...} as $FlowFixMe in objects',
  },

  {
    name: 'processColor type assertion',
    regex: /processColor\([^)]+\)\s+as\s+\$FlowFixMe/g,
    replacement: 'processColor($1)',
    description: 'Fix processColor(...) as $FlowFixMe',
  },

  // Import/export spacing fixes
  {
    name: 'import spacing',
    regex: /import\s+type\s*\{\s*([^}]+)\s*\}/g,
    replacement: (match, p1) => `import type { ${p1.trim()} }`,
    description: 'Fix import type spacing',
  },

  // Generic component patterns
  {
    name: 'simple component assignment',
    regex: /^(\s*const\s+\w+):\s*component\(\s*[^)]*\)\s*=\s*([^;]+);?$/gm,
    replacement: '$1 = $2;',
    description: 'Fix simple component assignments',
  },

  // Flow type assertion patterns
  {
    name: 'require Flow type assertion',
    regex: /\(\s*(require\([^)]+\))\s+as\s+\$FlowFixMe\s*\)/g,
    replacement: '$1',
    description: 'Fix (require(...) as $FlowFixMe)',
  },

  {
    name: 'general Flow type assertion',
    regex: /([^(]\s*)as\s+\$FlowFixMe/g,
    replacement: '$1',
    description: 'Fix expression as $FlowFixMe',
  },
];

// Find all relevant files
function findReactNativeFiles() {
  const patterns = [
    'node_modules/react-native/Libraries/**/*.js',
    'node_modules/react-native/src/**/*.js',
  ];

  let allFiles = [];

  try {
    // Use find command for better performance
    const findCmd = `find node_modules/react-native -name "*.js" -type f | grep -E "(Libraries|src)" | head -100`;
    const result = execSync(findCmd, { encoding: 'utf8' });
    allFiles = result
      .trim()
      .split('\n')
      .filter(f => f.length > 0);
  } catch (error) {
    console.warn('⚠️  Find command failed, using fallback method');
    // Fallback to specific known problematic files
    allFiles = [
      'node_modules/react-native/Libraries/ActionSheetIOS/ActionSheetIOS.js',
      'node_modules/react-native/Libraries/Components/ActivityIndicator/ActivityIndicator.js',
      'node_modules/react-native/Libraries/Components/Pressable/Pressable.js',
      'node_modules/react-native/Libraries/Components/TextInput/TextInput.js',
      'node_modules/react-native/Libraries/Components/SafeAreaView/SafeAreaView.js',
      'node_modules/react-native/Libraries/Components/ScrollView/ScrollView.js',
      'node_modules/react-native/Libraries/Components/View/View.js',
    ].filter(f => fs.existsSync(f));
  }

  return allFiles;
}

// Check if file contains problematic syntax
function hasProblematicSyntax(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return syntaxPatterns.some(pattern => {
      if (typeof pattern.regex === 'object' && pattern.regex.test) {
        return pattern.regex.test(content);
      }
      return false;
    });
  } catch (error) {
    return false;
  }
}

// Process files
function processFiles() {
  console.log('🔍 Scanning for React Native files with syntax issues...\n');

  const allFiles = findReactNativeFiles();
  const problematicFiles = allFiles.filter(hasProblematicSyntax);

  console.log(
    `Found ${problematicFiles.length} files with potential syntax issues:`
  );
  problematicFiles.forEach(file =>
    console.log(`  📄 ${path.relative(process.cwd(), file)}`)
  );
  console.log('');

  let totalFixes = 0;
  let processedFiles = 0;

  problematicFiles.forEach(filePath => {
    try {
      let content = fs.readFileSync(filePath, 'utf8');
      const originalContent = content;
      let fileFixes = 0;

      // Apply each pattern
      syntaxPatterns.forEach(pattern => {
        const beforeContent = content;

        if (typeof pattern.replacement === 'function') {
          content = content.replace(pattern.regex, pattern.replacement);
        } else {
          content = content.replace(pattern.regex, pattern.replacement);
        }

        if (content !== beforeContent) {
          const matches = beforeContent.match(pattern.regex) || [];
          fileFixes += matches.length;
          console.log(
            `  ✅ ${pattern.description}: ${
              matches.length
            } fix(es) in ${path.basename(filePath)}`
          );
        }
      });

      // Write back if changes were made
      if (content !== originalContent) {
        fs.writeFileSync(filePath, content, 'utf8');
        totalFixes += fileFixes;
        processedFiles++;
        console.log(
          `  💾 Updated ${path.basename(filePath)} (${fileFixes} total fixes)\n`
        );
      }
    } catch (error) {
      console.error(`❌ Error processing ${filePath}:`, error.message);
    }
  });

  return { totalFixes, processedFiles };
}

// Main execution
async function main() {
  try {
    const { totalFixes, processedFiles } = processFiles();

    console.log(`\n🎉 Processing complete!`);
    console.log(`   📊 Files processed: ${processedFiles}`);
    console.log(`   🔧 Total fixes applied: ${totalFixes}\n`);

    if (totalFixes > 0) {
      console.log('📦 Generating patch file...');
      execSync('npx patch-package react-native', { stdio: 'inherit' });
      console.log('✅ Patch file generated successfully!\n');

      console.log('🚀 Ready to test! Run: npx expo start');
    } else {
      console.log(
        '✨ No syntax issues found - your React Native setup looks good!'
      );
    }
  } catch (error) {
    console.error('❌ Fatal error:', error.message);
    process.exit(1);
  }
}

// Run the fixer
main();
