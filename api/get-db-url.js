#!/usr/bin/env node

// Script to dynamically get the correct database URL
const { execSync } = require('child_process');

function getDatabaseUrl() {
  try {
    // Check if we're in a DDEV environment
    const ddevDescribe = execSync('ddev describe --json-output 2>/dev/null', { encoding: 'utf8' });
    const ddevInfo = JSON.parse(ddevDescribe);
    
    // Find the database service
    const dbService = ddevInfo.raw.services.find(service => service.name === 'db');
    if (dbService && dbService.host_ports) {
      const dbPort = dbService.host_ports.find(port => port.container_port === 3306);
      if (dbPort) {
        return `mysql://db:db@127.0.0.1:${dbPort.host_port}/db`;
      }
    }
  } catch (error) {
    // DDEV not available or not in DDEV project
  }
  
  // Fallback to default local development
  return 'mysql://db:db@127.0.0.1:3306/db';
}

console.log(getDatabaseUrl());
