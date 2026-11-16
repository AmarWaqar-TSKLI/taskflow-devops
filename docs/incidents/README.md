# incidents — post-incident notes

**Owner:** Member 5. One file per incident: `YYYY-MM-DD-<short-name>.md`. Copy the template below.

```markdown
# Incident: <title>

| | |
|---|---|
| Date / time (start → end) | |
| Duration | |
| Impact | What users saw |
| Detected by | Which alarm / SNS email |

## Timeline
- hh:mm — change made / failure started
- hh:mm — alarm fired
- hh:mm — diagnosis
- hh:mm — fix applied
- hh:mm — recovered (alarm OK)

## Diagnosis
Which metrics and log lines showed the cause (screenshots in docs/evidence/).

## Root cause

## Fix

## What we'd change to prevent it
```
