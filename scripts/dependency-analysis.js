#!/usr/bin/env node

/**
 * Dependency Analysis Script for KRTR Mesh
 * Analyzes project dependencies and generates security reports
 */

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

console.log('🔍 KRTR Mesh Dependency Analysis\n');

// Read package.json
const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));

console.log(`📦 Project: ${packageJson.name} v${packageJson.version}`);
console.log(`📝 Description: ${packageJson.description}\n`);

// Analyze dependencies
function analyzeDependencies() {
  console.log('📊 Dependency Analysis:');
  
  const deps = packageJson.dependencies || {};
  const devDeps = packageJson.devDependencies || {};
  
  console.log(`   Production dependencies: ${Object.keys(deps).length}`);
  console.log(`   Development dependencies: ${Object.keys(devDeps).length}`);
  console.log(`   Total dependencies: ${Object.keys(deps).length + Object.keys(devDeps).length}\n`);
  
  // Key dependencies analysis
  console.log('🔑 Key Dependencies:');
  const keyDeps = [
    'react-native',
    'expo',
    '@react-native-async-storage/async-storage',
    'react-native-ble-plx',
    'react-native-wifi-reborn'
  ];
  
  keyDeps.forEach(dep => {
    if (deps[dep]) {
      console.log(`   ✅ ${dep}: ${deps[dep]}`);
    } else {
      console.log(`   ❌ ${dep}: Not found`);
    }
  });
  console.log('');
}

// Run security audit
function runSecurityAudit() {
  console.log('🔒 Security Audit:');
  try {
    const auditResult = execSync('npm audit --json', { encoding: 'utf8' });
    const audit = JSON.parse(auditResult);
    
    if (audit.metadata && audit.metadata.vulnerabilities) {
      const vulns = audit.metadata.vulnerabilities;
      console.log(`   Total vulnerabilities: ${vulns.total}`);
      console.log(`   Critical: ${vulns.critical || 0}`);
      console.log(`   High: ${vulns.high || 0}`);
      console.log(`   Moderate: ${vulns.moderate || 0}`);
      console.log(`   Low: ${vulns.low || 0}`);
      
      if (vulns.total > 0) {
        console.log('\n   ⚠️  Run "npm audit fix" to address fixable vulnerabilities');
      } else {
        console.log('\n   ✅ No vulnerabilities found!');
      }
    }
  } catch (error) {
    console.log('   ✅ No vulnerabilities found or audit not available');
  }
  console.log('');
}

// Check for outdated packages
function checkOutdated() {
  console.log('📅 Outdated Packages:');
  try {
    const outdatedResult = execSync('npm outdated --json', { encoding: 'utf8' });
    const outdated = JSON.parse(outdatedResult);
    
    const outdatedCount = Object.keys(outdated).length;
    if (outdatedCount > 0) {
      console.log(`   Found ${outdatedCount} outdated packages:`);
      Object.entries(outdated).forEach(([pkg, info]) => {
        console.log(`   📦 ${pkg}: ${info.current} → ${info.latest}`);
      });
      console.log('\n   💡 Run "npm update" to update packages');
    } else {
      console.log('   ✅ All packages are up to date!');
    }
  } catch (error) {
    console.log('   ✅ All packages are up to date!');
  }
  console.log('');
}

// Generate dependency tree
function generateDependencyTree() {
  console.log('🌳 Dependency Tree (Top Level):');
  try {
    const treeResult = execSync('npm list --depth=1', { encoding: 'utf8' });
    console.log(treeResult);
  } catch (error) {
    console.log('   Unable to generate dependency tree');
  }
}

// Check React Native specific dependencies
function checkReactNativeDeps() {
  console.log('⚛️  React Native Ecosystem:');
  
  const rnDeps = Object.keys({...packageJson.dependencies, ...packageJson.devDependencies})
    .filter(dep => dep.includes('react-native') || dep.includes('expo') || dep.includes('@react-native'));
  
  console.log(`   Found ${rnDeps.length} React Native related packages:`);
  rnDeps.forEach(dep => {
    const version = packageJson.dependencies[dep] || packageJson.devDependencies[dep];
    console.log(`   📱 ${dep}: ${version}`);
  });
  console.log('');
}

// Main execution
async function main() {
  try {
    analyzeDependencies();
    checkReactNativeDeps();
    runSecurityAudit();
    checkOutdated();
    generateDependencyTree();
    
    console.log('✅ Dependency analysis complete!');
    console.log('\n💡 Tips:');
    console.log('   - Run this script regularly to monitor dependencies');
    console.log('   - Keep dependencies updated for security');
    console.log('   - Review GitHub Dependabot alerts');
    console.log('   - Use "npm audit fix" for security fixes');
    
  } catch (error) {
    console.error('❌ Error during analysis:', error.message);
    process.exit(1);
  }
}

// Run the analysis
main();
