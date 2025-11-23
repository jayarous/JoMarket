#!/usr/bin/env pwsh
# Deploy SLA Monitor Edge Function to Supabase

$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying sla-monitor function..." -ForegroundColor Cyan

# Validate code before deploying
Write-Host "📋 Running validation checks..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\supabase\functions\sla-monitor"

try {
    # Format check
    Write-Host "  - Checking formatting..." -ForegroundColor Gray
    deno fmt --check
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Format check failed. Run 'deno fmt' to fix." -ForegroundColor Red
        exit 1
    }

    # Lint
    Write-Host "  - Running linter..." -ForegroundColor Gray
    deno lint
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Lint check failed. Fix the issues above." -ForegroundColor Red
        exit 1
    }

    # Type check
    Write-Host "  - Type checking..." -ForegroundColor Gray
    deno check index.ts
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Type check failed. Fix the issues above." -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ All checks passed!" -ForegroundColor Green
} finally {
    Pop-Location
}

# Deploy to Supabase
Write-Host "📦 Deploying to Supabase..." -ForegroundColor Yellow
supabase functions deploy sla-monitor --project-ref qjwnudofsiznvfcgzwuv

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Test the function: Invoke it manually in Supabase Dashboard"
    Write-Host "  2. Set up cron schedule in Supabase (every 15 minutes recommended)"
    Write-Host "  3. Monitor logs: supabase functions logs sla-monitor"
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}
