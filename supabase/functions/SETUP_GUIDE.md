# Edge Functions Setup Guide

## Prerequisites Installation

You need to install **Deno** and **Supabase CLI** before you can work with Edge Functions.

### 1. Install Deno

**Option A: Using PowerShell (Recommended)**
```powershell
irm https://deno.land/install.ps1 | iex
```

**Option B: Using Scoop**
```powershell
scoop install deno
```

**Option C: Using Chocolatey**
```powershell
choco install deno
```

After installation, restart your terminal and verify:
```powershell
deno --version
```

### 2. Install Supabase CLI

**Option A: Using PowerShell (Recommended)**
```powershell
# Install Scoop first if you don't have it
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Then install Supabase CLI
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

**Option B: Direct Download**
Download from: https://github.com/supabase/cli/releases

After installation, verify:
```powershell
supabase --version
```

## Setup Steps

### 1. Authenticate with Supabase

Log in once to store your access token:
```powershell
supabase login
```

This will open a browser window for authentication.

### 2. Pin Dependencies

Generate the lock file to ensure consistent dependency versions:
```powershell
cd supabase/functions/sla-monitor
deno cache --lock=deno.lock --lock-write index.ts
```

This creates `deno.lock` which should be committed to version control.

### 3. Environment Setup

Your environment file is already set up at `env/.env`. Make sure it contains:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY` (needed for the function)

## Development Workflow

### Run Code Quality Checks

The `deno.json` file now includes these tasks:

```powershell
# In supabase/functions/sla-monitor/

# Format code
deno task fmt

# Check formatting without modifying
deno task fmt:check

# Run linter
deno task lint

# Type check
deno task check

# Run all validation checks
deno task validate
```

### Test Locally

Use the provided script to serve the function locally:
```powershell
.\scripts\serve-sla-monitor.ps1
```

Or run directly:
```powershell
supabase functions serve sla-monitor --env-file env/.env --no-verify-jwt
```

Then test with:
```powershell
curl http://localhost:54321/functions/v1/sla-monitor
```

### Deploy to Production

Use the deployment script:
```powershell
.\scripts\deploy-sla-monitor.ps1
```

Or deploy directly:
```powershell
supabase functions deploy sla-monitor --project-ref qjwnudofsiznvfcgzwuv
```

The deployment script automatically runs validation checks before deploying.

## Setting Up Scheduled Execution

After deploying, set up a cron schedule in Supabase Dashboard:

1. Go to **Database** → **Cron Jobs** (or use pg_cron)
2. Create a new cron job to call the function every 15 minutes:

```sql
SELECT cron.schedule(
  'sla-monitor-job',
  '*/15 * * * *',  -- Every 15 minutes
  $$
  SELECT net.http_post(
    url:='https://qjwnudofsiznvfcgzwuv.supabase.co/functions/v1/sla-monitor',
    headers:=jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    )
  ) AS request_id;
  $$
);
```

Alternatively, use the Supabase Dashboard:
- Go to **Edge Functions** → **sla-monitor**
- Click **Settings** → **Add Trigger**
- Set schedule to `*/15 * * * *` (every 15 minutes)

## Monitoring

View function logs:
```powershell
supabase functions logs sla-monitor --project-ref qjwnudofsiznvfcgzwuv
```

Or check in the Supabase Dashboard under **Edge Functions** → **sla-monitor** → **Logs**.

## Quick Reference

| Task | Command |
|------|---------|
| Serve locally | `.\scripts\serve-sla-monitor.ps1` |
| Deploy | `.\scripts\deploy-sla-monitor.ps1` |
| Validate code | `deno task validate` |
| Format code | `deno task fmt` |
| View logs | `supabase functions logs sla-monitor` |

## Troubleshooting

### "Command not found: deno" or "supabase"
- Make sure you've installed Deno and Supabase CLI (see Prerequisites)
- Restart your terminal after installation
- Check PATH environment variable

### Function fails to deploy
- Run `deno task validate` to check for code issues
- Ensure you're logged in: `supabase login`
- Verify project_id in `supabase/config.toml`

### Local serving fails
- Check that `env/.env` exists and has the required variables
- Ensure no other process is using port 54321
- Try with `--no-verify-jwt` flag for testing

### Lock file issues
- Delete `deno.lock` and regenerate: `deno cache --lock=deno.lock --lock-write index.ts`
- Check that all imports in `index.ts` are accessible

## Next Steps

Once everything is working:
1. ✅ Run validation checks before each commit
2. ✅ Test locally with `serve-sla-monitor.ps1`
3. ✅ Deploy with `deploy-sla-monitor.ps1`
4. ✅ Set up cron schedule in Supabase
5. ✅ Monitor function logs regularly
