# Cloud Workflows for Backfill Orchestration

This directory contains Cloud Workflows for orchestrating historical data backfills.

## What is Cloud Workflows?

Cloud Workflows is a serverless orchestration platform that:
- Executes multi-step processes
- Provides automatic retry and error handling
- Offers built-in monitoring
- Costs ~$0.01 per 1000 steps (essentially free)

## Available Workflows

### `quarterly_backfill_workflow.yaml`
Orchestrates Q1 2020 backfill by iterating through 90 dates and executing Cloud Run jobs.

**Features:**
- Automatic retry on failure
- Built-in logging and monitoring
- Error tracking
- Execution summary

## Quick Start

### 1. Deploy Workflow

```bash
cd ~/Desktop/chicago-bi-app/workflows

# Deploy to GCP
./deploy_workflow.sh
```

### 2. Execute Workflow

```bash
# For taxi dataset
gcloud workflows execute quarterly-backfill-workflow \
  --location=us-central1 \
  --data='{"dataset":"taxi"}'

# For TNP dataset
gcloud workflows execute quarterly-backfill-workflow \
  --location=us-central1 \
  --data='{"dataset":"tnp"}'
```

### 3. Monitor Execution

**Via gcloud:**
```bash
# List executions
gcloud workflows executions list quarterly-backfill-workflow \
  --location=us-central1

# Get execution details
gcloud workflows executions describe <EXECUTION_ID> \
  --workflow=quarterly-backfill-workflow \
  --location=us-central1
```

**Via Cloud Console:**
1. Go to [Cloud Workflows](https://console.cloud.google.com/workflows)
2. Click `quarterly-backfill-workflow`
3. View executions tab
4. Click execution to see detailed logs

## Cost

- Workflow execution: $0.01 per 1000 steps
- Q1 2020 backfill: 90 steps = **$0.0009** (less than 1 cent)
- Cloud Run executions: 90 × $0.012 = $1.08
- **Total: ~$1.08**

## Benefits vs Bash Scripts

| Feature | Bash Script | Cloud Workflows |
|---------|-------------|-----------------|
| Monitoring | Manual logs | Built-in UI |
| Retry | Manual | Automatic |
| Execution history | No | Yes |
| Pause/resume | tmux only | Built-in |
| Error tracking | Manual | Automatic |

## Customization

To modify for different quarters or datasets, edit `quarterly_backfill_workflow.yaml`:

```yaml
# Change date range
- start_date: "2020-04-01"  # Q2 start
- end_date: "2020-06-30"    # Q2 end
```

Then redeploy:
```bash
./deploy_workflow.sh
```

See `/docs/RUN_BACKFILL_ON_CLOUD.md` for complete documentation.
