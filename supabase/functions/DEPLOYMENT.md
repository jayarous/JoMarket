# Deploying the SLA Monitor Edge Function

This guide covers deploying the SLA monitoring function to Supabase.

## Prerequisites

1. **Supabase CLI installed**
   ```powershell
   # Install via npm
   npm install -g supabase
   
   # Or via Scoop (Windows)
   scoop install supabase
   ```

2. **Supabase project linked**
   ```powershell
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   ```

## Deployment Steps

### 1. Deploy the Function

```powershell
# Navigate to project root
cd c:\Users\jayar\Desktop\JoMarket

# Deploy the function
supabase functions deploy sla-monitor
```

### 2. Set Up Cron Schedule

```powershell
# Schedule to run every 15 minutes
supabase functions schedule sla-monitor "*/15 * * * *"
```

### 3. Verify Deployment

```powershell
# List all functions
supabase functions list

# Check if schedule is active
supabase functions schedule list
```

### 4. Test the Function

```powershell
# Invoke manually to test
supabase functions invoke sla-monitor --method POST

# Watch logs
supabase functions logs sla-monitor --tail
```

## Expected Output

Successful deployment:
```
Deployed Function sla-monitor on project YOUR_PROJECT
Function URL: https://YOUR_PROJECT_REF.supabase.co/functions/v1/sla-monitor
```

Successful schedule:
```
Scheduled sla-monitor to run with cron expression: */15 * * * *
```

Test invocation:
```json
{
  "success": true,
  "message": "SLA monitoring completed",
  "stats": {
    "total_monitored": 10,
    "marked_at_risk": 2,
    "marked_breached": 0,
    "errors": 0
  },
  "timestamp": "2025-11-13T10:00:00.000Z"
}
```

## Monitoring

### View Logs

```powershell
# Tail logs in real-time
supabase functions logs sla-monitor --tail

# View last 100 logs
supabase functions logs sla-monitor --limit 100
```

### Check Function Health

```powershell
# Get function details
supabase functions get sla-monitor

# List recent invocations
supabase functions logs sla-monitor --limit 10
```

## Troubleshooting

### Function not found

If deployment fails with "function not found":
1. Ensure you're in the correct directory
2. Check that `supabase/functions/sla-monitor/` exists
3. Verify `index.ts` is in the directory

### Permission errors

If you see permission errors:
1. Verify you're logged in: `supabase login`
2. Check project is linked: `supabase projects list`
3. Ensure you have admin access to the project

### Schedule not triggering

If the function doesn't run automatically:
1. Check schedule is active: `supabase functions schedule list`
2. Verify cron syntax is correct
3. Check function logs for errors
4. Wait 15 minutes for first execution

### Environment variables

The function automatically receives:
- `SUPABASE_URL` - Your project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Admin access key

These are injected by Supabase and don't need manual configuration.

## Manual Testing

### Test locally before deployment

```powershell
# Start local Supabase (if not already running)
supabase start

# Serve the function locally
supabase functions serve sla-monitor

# In another terminal, invoke it
curl -i --location --request POST 'http://localhost:54321/functions/v1/sla-monitor' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

### Test in production

```powershell
# Invoke remotely
supabase functions invoke sla-monitor --method POST

# Check response and logs
supabase functions logs sla-monitor --limit 1
```

## Updating the Function

When you make changes to `index.ts`:

```powershell
# Redeploy
supabase functions deploy sla-monitor

# Schedule is preserved - no need to reschedule
# Check logs to verify new version is running
supabase functions logs sla-monitor --tail
```

## Disabling the Function

If you need to temporarily disable:

```powershell
# Remove schedule
supabase functions unschedule sla-monitor

# Optionally delete the function
supabase functions delete sla-monitor
```

## Production Checklist

- [ ] Function deployed successfully
- [ ] Cron schedule configured (every 15 minutes)
- [ ] Test invocation returns success
- [ ] Logs show expected output
- [ ] Database tables have correct permissions
- [ ] Monitor logs for first 24 hours
- [ ] Set up alerts for function failures (optional)

## Next Steps

After deployment:
1. Monitor logs for the first hour
2. Check that SLA statuses are updating correctly
3. Verify moderation_actions are being logged
4. Consider implementing email notifications
5. Set up monitoring/alerting for function failures

## Related Files

- `supabase/functions/sla-monitor/index.ts` - Function code
- `supabase/functions/sla-monitor/deno.json` - Deno configuration
- `supabase/functions/sla-monitor/README.md` - Function documentation
- `SUPPORT_MODERATION_GUIDE.md` - Overall system guide
