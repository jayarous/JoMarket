# SLA Monitor Edge Function

Automated monitoring function that runs every 15 minutes to update support
ticket SLA statuses.

## Overview

This Edge Function monitors all open moderation queue items and updates their
SLA status based on time remaining until deadline:

- **Normal**: More than 2 hours until deadline
- **At Risk**: Less than 2 hours until deadline
- **Breached**: Past the deadline

## Configuration

### Cron Schedule

The function should be scheduled to run every 15 minutes using Supabase Edge
Functions cron:

```bash
supabase functions schedule sla-monitor "*/15 * * * *"
```

### Environment Variables

Required environment variables (automatically provided by Supabase):

- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Service role key for admin operations

## Deployment

### Deploy the function

```bash
supabase functions deploy sla-monitor
```

### Set up the cron schedule

```bash
# Run every 15 minutes
supabase functions schedule sla-monitor "*/15 * * * *"
```

### Verify deployment

```bash
# List all functions
supabase functions list

# Check function logs
supabase functions logs sla-monitor
```

## Testing

### Manual invocation

```bash
# Test locally
supabase functions serve sla-monitor

# Invoke manually
curl -i --location --request POST 'http://localhost:54321/functions/v1/sla-monitor' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

### Production test

```bash
supabase functions invoke sla-monitor --method POST
```

## Monitoring

The function logs detailed information about:

- Total items monitored
- Number of items marked as "at risk"
- Number of items marked as "breached"
- Any errors encountered

Check logs regularly:

```bash
supabase functions logs sla-monitor --tail
```

## Response Format

```json
{
  "success": true,
  "message": "SLA monitoring completed",
  "stats": {
    "total_monitored": 25,
    "marked_at_risk": 3,
    "marked_breached": 1,
    "errors": 0
  },
  "timestamp": "2025-11-13T10:00:00.000Z"
}
```

## Error Handling

The function:

- Continues processing even if individual items fail
- Logs all errors for troubleshooting
- Returns aggregate error count in stats
- Uses service role key for admin-level access

## Future Enhancements

- [ ] Send email notifications for breached SLAs
- [ ] Send push notifications to assigned admins
- [ ] Escalate to senior admins after X hours
- [ ] Auto-assign tickets based on workload
- [ ] Generate daily SLA performance reports

## Troubleshooting

### Function not running

Check if the cron schedule is active:

```bash
supabase functions schedule list
```

### Permission errors

Ensure the service role key has proper permissions to:

- Read from `moderation_queue`
- Update `moderation_queue`
- Insert into `moderation_actions`

### No items being updated

Verify that:

- Items have `status` in ('new', 'open')
- Items have a non-null `sla_deadline`
- The `sla_deadline` is in the correct format (ISO 8601)

## Related Documentation

- [SUPPORT_MODERATION_GUIDE.md](../../../SUPPORT_MODERATION_GUIDE.md)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Deno Runtime](https://deno.land/manual)
