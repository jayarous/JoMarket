#!/usr/bin/env pwsh
# Serve SLA Monitor Edge Function locally for testing

$ErrorActionPreference = "Stop"

Write-Host "🔧 Starting local Supabase Functions server..." -ForegroundColor Cyan
Write-Host "📍 Function: sla-monitor" -ForegroundColor Gray
Write-Host "🔑 Using env file: env/.env" -ForegroundColor Gray
Write-Host ""

# Check if env file exists
if (-not (Test-Path "$PSScriptRoot\..\env\.env")) {
    Write-Host "❌ Error: env/.env file not found" -ForegroundColor Red
    Write-Host "Create it from env/.env.example and add your credentials" -ForegroundColor Yellow
    exit 1
}

# Serve the function
supabase functions serve sla-monitor --env-file env/.env --no-verify-jwt

# Note: Use --no-verify-jwt for local testing to bypass JWT verification
# Remove this flag if you want to test with proper authentication
