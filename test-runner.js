#!/usr/bin/env node

/**
 * Comprehensive Test Runner for Hospital Tasks Application
 * Runs both frontend (Vitest) and backend (Jest) tests
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

function colorize(text, color) {
  return `${colors[color]}${text}${colors.reset}`;
}

function log(message, color = 'reset') {
  console.log(colorize(message, color));
}

function runCommand(command, args, cwd, description) {
  return new Promise((resolve, reject) => {
    log(`\n${colorize('▶', 'blue')} ${description}`, 'bright');
    log(`Running: ${command} ${args.join(' ')}`, 'cyan');
    
    const child = spawn(command, args, {
      cwd,
      stdio: 'inherit',
      shell: true
    });

    child.on('close', (code) => {
      if (code === 0) {
        log(`${colorize('✓', 'green')} ${description} completed successfully`, 'green');
        resolve(code);
      } else {
        log(`${colorize('✗', 'red')} ${description} failed with code ${code}`, 'red');
        reject(new Error(`${description} failed`));
      }
    });

    child.on('error', (error) => {
      log(`${colorize('✗', 'red')} Error running ${description}: ${error.message}`, 'red');
      reject(error);
    });
  });
}

async function runTests() {
  const startTime = Date.now();
  
  log(colorize('\n🧪 Hospital Tasks - Comprehensive Test Suite', 'bright'));
  log(colorize('=' .repeat(50), 'cyan'));

  try {
    // Frontend tests
    log(colorize('\n📱 Frontend Tests (Vitest)', 'magenta'));
    log(colorize('-'.repeat(30), 'magenta'));
    
    await runCommand(
      'npm',
      ['run', 'test:run'],
      __dirname,
      'Frontend unit tests'
    );

    // Backend tests
    log(colorize('\n🔧 Backend Tests (Jest)', 'magenta'));
    log(colorize('-'.repeat(30), 'magenta'));
    
    await runCommand(
      'npm',
      ['test'],
      join(__dirname, 'api'),
      'Backend unit tests'
    );

    // Success summary
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    log(colorize('\n🎉 All Tests Passed!', 'green'));
    log(colorize(`Total time: ${duration}s`, 'cyan'));
    
  } catch (error) {
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    log(colorize('\n❌ Test Suite Failed!', 'red'));
    log(colorize(`Total time: ${duration}s`, 'cyan'));
    log(colorize(`Error: ${error.message}`, 'red'));
    process.exit(1);
  }
}

async function runCoverage() {
  log(colorize('\n📊 Running Coverage Reports', 'bright'));
  log(colorize('=' .repeat(50), 'cyan'));

  try {
    // Frontend coverage
    log(colorize('\n📱 Frontend Coverage', 'magenta'));
    await runCommand(
      'npm',
      ['run', 'test:coverage'],
      __dirname,
      'Frontend coverage report'
    );

    // Backend coverage
    log(colorize('\n🔧 Backend Coverage', 'magenta'));
    await runCommand(
      'npm',
      ['run', 'test:coverage'],
      join(__dirname, 'api'),
      'Backend coverage report'
    );

    log(colorize('\n📊 Coverage reports generated successfully!', 'green'));
    
  } catch (error) {
    log(colorize(`\n❌ Coverage generation failed: ${error.message}`, 'red'));
    process.exit(1);
  }
}

async function runWatch() {
  log(colorize('\n👀 Running Tests in Watch Mode', 'bright'));
  log(colorize('Choose which tests to watch:', 'cyan'));
  log('1. Frontend tests (Vitest)');
  log('2. Backend tests (Jest)');
  
  // For simplicity, default to frontend watch mode
  // In a real implementation, you could add interactive selection
  
  try {
    await runCommand(
      'npm',
      ['test'],
      __dirname,
      'Frontend tests in watch mode'
    );
  } catch (error) {
    log(colorize(`\n❌ Watch mode failed: ${error.message}`, 'red'));
    process.exit(1);
  }
}

function showHelp() {
  log(colorize('\n🧪 Hospital Tasks Test Runner', 'bright'));
  log(colorize('=' .repeat(40), 'cyan'));
  log('\nUsage: node test-runner.js [command]');
  log('\nCommands:');
  log('  test      Run all tests (default)');
  log('  coverage  Run tests with coverage reports');
  log('  watch     Run tests in watch mode');
  log('  help      Show this help message');
  log('\nExamples:');
  log('  node test-runner.js');
  log('  node test-runner.js coverage');
  log('  node test-runner.js watch');
}

// Main execution
const command = process.argv[2] || 'test';

switch (command) {
  case 'test':
    runTests();
    break;
  case 'coverage':
    runCoverage();
    break;
  case 'watch':
    runWatch();
    break;
  case 'help':
  case '--help':
  case '-h':
    showHelp();
    break;
  default:
    log(colorize(`Unknown command: ${command}`, 'red'));
    showHelp();
    process.exit(1);
}
