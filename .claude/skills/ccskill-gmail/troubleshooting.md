# Troubleshooting

Common issues and solutions for the Gmail Skill.

> **Recommended**: Using the `ccskill-gmail api` command automatically applies `-L`, `--max-time 60`, `--data`, and Bearer authentication, which avoids most of the issues described below.

---

## Quick Reference

| Symptom | Cause | Solution |
|---------|-------|----------|
| HTML returned (login page) | No authentication / token expired | Run `clasp login` |
| Timeout | Cold start | Retry (`--max-time 60` is already applied automatically) |
| Unknown action | Incorrect GET/POST usage | Use the correct get / post subcommand |
| Invalid JSON | JSON syntax error | Validate JSON beforehand |
| Thread/Message not found | Wrong ID or deleted | Get the latest ID with `search` |
| Japanese search not working | Encoding issue when using curl directly | Use the get subcommand (auto-encodes) |
| Endpoint not set | Broken project install | Run `ccskill-gmail update` |
| No account configured (NO_ACCOUNT) | No central account and no project install in this directory | Run `ccskill-gmail account add` (or `cd` into an installed project) |
| Unknown account (UNKNOWN_ACCOUNT) | `--account` value is not registered | Check with `ccskill-gmail account list` |
| Action "xxx" is denied by permissions config | Denied by permissions setting | Remove the action from `permissions.deny` in `config.js` |

---

## Detailed Solutions

### Action denied by permissions config

**Symptom**: `{"ok":false,"error":"Action \"move_to_trash\" is denied by permissions config. ..."}`

**Cause**: The action is included in `permissions.deny` in `config.js` (`move_to_trash` is disabled by default)

**Solution**: the steps depend on your setup.

- **Account-shared setup (default)** — the project has only `binding.json` and no local `config.js`:
  1. Edit `~/.ccskill-gmail/gas/<clasp_user>/config.js` and remove the action from `permissions.deny`
  2. Re-deploy the account's shared GAS:
     ```bash
     ccskill-gmail account update
     ```
- **Dedicated per-project setup** — the project has its own `config.js` and `.clasp.json`:
  1. Edit `.ccskill-gmail/config.js` and remove the action from `permissions.deny`
  2. Re-deploy:
     ```bash
     ccskill-gmail apply-config
     ```

`apply-config` applies to dedicated installs only. For the account-shared setup, use `account update` (running `apply-config` there prints the same guidance).

**Example**: Enabling `move_to_trash`
```javascript
// Before
permissions: {
  deny: [
    'move_to_trash',
  ]
}

// After
permissions: {
  deny: [
    // 'move_to_trash',  // Comment out or remove
  ]
}
```

---

### Authentication Error (401 / Access Denied)

**Symptom**:
- Response is HTML (Google login page)
- Error like `{"ok":false,"error":"Authorization required"}`

**Causes and Solutions**:

1. **Not logged into clasp**
   ```bash
   clasp login
   ```

2. **Token expired (auto-refresh failed)**
   ```bash
   # Check ~/.clasprc.json
   jq '.tokens.default.expiry_date' ~/.clasprc.json
   # Re-login
   clasp login
   ```

3. **Deployment is still set to "Anyone"**
   - Check the deployment settings in the GAS editor
   - Change to "Only myself" (MYSELF) and redeploy

4. **Using curl directly instead of the api script**
   ```bash
   # NG: Direct curl (no Bearer token)
   curl -sL "https://script.google.com/.../exec?action=list_labels"

   # OK: Via api script (auto-authentication)
   ccskill-gmail api get action=list_labels
   ```

---

### Timeout Error

**Symptom**: Request hangs with no response

**Cause**: GAS cold start (initial startup delay)

**Solution**: The api script already sets `--max-time 60` internally. If it still times out, retry.

```bash
# Retry
ccskill-gmail api get action=list_labels
```

---

### Unknown action Error

**Symptom**: `{"ok":false,"error":"Unknown action: search"}`

**Cause**: Incorrect GET/POST usage

**Solution**: Use the `get` subcommand for read operations and `post` for write operations

```bash
# OK: search with get
ccskill-gmail api get action=search query="is:unread"

# NG: calling search with post
ccskill-gmail api post '{"action":"search","query":"is:unread"}'
```

---

### Invalid JSON Error

**Symptom**: `{"ok":false,"error":"Invalid JSON in request body"}`

**Cause**: JSON syntax error (quotes, commas, etc.)

**Solution**:
```bash
# Validate JSON beforehand
echo '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}' | jq .

# Wrap in single quotes (prevents shell variable expansion)
ccskill-gmail api post '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}'
```

---

### Thread not found / Message not found

**Symptom**: `{"ok":false,"error":"Thread not found: xxx"}`

**Cause**:
- Incorrect thread/message ID
- The email has been deleted

**Solution**: Re-fetch the latest ID using `search`

```bash
ccskill-gmail api get action=search query="is:unread" maxResults=5
```

---

### Japanese Search Issues

**Symptom**: Searches containing Japanese do not work correctly

**Previous issue**: Japanese text needed to be URL-encoded

**Current solution**: The get subcommand automatically URL-encodes values, so you can pass Japanese text as-is:

```bash
# OK: Japanese can be used directly
ccskill-gmail api get action=search query="from:田中太郎"

# Manual encoding is not needed
```

---

### Permission Error

**Symptom**: Permission error during deployment, or 403 error on API calls

**Cause**: Gmail access permissions have not been authorized

**Solution**:
1. Open "Deploy" -> "Manage deployments" in the GAS editor
2. On the "This app isn't verified" screen, click "Advanced" -> "Go to (unsafe)" to authorize

---

### Endpoint Not Set

**Symptom**: `{"ok":false,"error":"GMAIL_ENDPOINT not set..."}`

**Cause**: The project install in this directory is broken (metadata exists but has no endpoint)

**Solution**:
```bash
# update repairs the metadata
ccskill-gmail update
```

---

### No Account Configured (NO_ACCOUNT)

**Symptom**: `{"ok":false,"error":"No account configured...","error_code":"NO_ACCOUNT"}`

**Cause**: This directory has no project install AND no account is registered in the central registry

**Solution**:
```bash
# Register an account once (works from any directory afterwards)
ccskill-gmail account add

# Or check what is registered / which account would be used
ccskill-gmail account list
ccskill-gmail api whoami
```

---

## Debugging Methods

### Health Check

```bash
ccskill-gmail api get
# Expected: {"ok":true,"data":{"status":"ok","message":"Gmail Skill is running","version":"1.0.0"}}
```

### Environment Diagnosis

```bash
# Checks clasp login, OAuth tokens, accounts.json, endpoint connectivity
ccskill-gmail doctor
```

### Account / Endpoint Verification

```bash
ccskill-gmail api whoami
# Shows the resolved account, its source (flag/env/binding/binding-legacy/default/single) and endpoint
```

### Response Inspection

```bash
# Pretty-print the response
ccskill-gmail api get action=list_labels | jq .
```
