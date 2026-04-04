# Troubleshooting

Common issues and solutions for the Gmail Skill.

> **Recommended**: Using the `.ccskill-gmail/api` standalone script automatically applies `-L`, `--max-time 60`, `--data`, and Bearer authentication, which avoids most of the issues described below.

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
| Endpoint not set | Missing endpoint file / install not completed | Run `ccskill-gmail update` |
| Action "xxx" is denied by permissions config | Denied by permissions setting | Remove the action from `permissions.deny` in `config.js` |

---

## Detailed Solutions

### Action denied by permissions config

**Symptom**: `{"ok":false,"error":"Action \"move_to_trash\" is denied by permissions config. ..."}`

**Cause**: The action is included in `permissions.deny` in `config.js` (`move_to_trash` is disabled by default)

**Solution**:

1. Edit `config.js` at the install location and remove the action from the `permissions.deny` array
2. Redeploy
   ```bash
   ccskill-gmail apply-config
   ```

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
   .ccskill-gmail/api get action=list_labels
   ```

---

### Timeout Error

**Symptom**: Request hangs with no response

**Cause**: GAS cold start (initial startup delay)

**Solution**: The api script already sets `--max-time 60` internally. If it still times out, retry.

```bash
# Retry
.ccskill-gmail/api get action=list_labels
```

---

### Unknown action Error

**Symptom**: `{"ok":false,"error":"Unknown action: search"}`

**Cause**: Incorrect GET/POST usage

**Solution**: Use the `get` subcommand for read operations and `post` for write operations

```bash
# OK: search with get
.ccskill-gmail/api get action=search query="is:unread"

# NG: calling search with post
.ccskill-gmail/api post '{"action":"search","query":"is:unread"}'
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
.ccskill-gmail/api post '{"action":"create_draft","to":"test@example.com","subject":"Test","body":"Hello"}'
```

---

### Thread not found / Message not found

**Symptom**: `{"ok":false,"error":"Thread not found: xxx"}`

**Cause**:
- Incorrect thread/message ID
- The email has been deleted

**Solution**: Re-fetch the latest ID using `search`

```bash
.ccskill-gmail/api get action=search query="is:unread" maxResults=5
```

---

### Japanese Search Issues

**Symptom**: Searches containing Japanese do not work correctly

**Previous issue**: Japanese text needed to be URL-encoded

**Current solution**: The get subcommand automatically URL-encodes values, so you can pass Japanese text as-is:

```bash
# OK: Japanese can be used directly
.ccskill-gmail/api get action=search query="from:田中太郎"

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

**Cause**: The `.ccskill-gmail/endpoint` file does not exist, or install/update has not been completed

**Solution**:
```bash
# update auto-generates the endpoint file
ccskill-gmail update

# Check the endpoint file content
cat .ccskill-gmail/endpoint
```

---

## Debugging Methods

### Health Check

```bash
.ccskill-gmail/api get
# Expected: {"ok":true,"data":{"status":"ok","message":"Gmail Skill is running","version":"1.0.0"}}
```

### Token Verification

```bash
# Source auth.sh directly to check the token (for debugging)
source .ccskill-gmail/auth.sh && gas_token
# If an access token is displayed, it is working correctly
```

### Endpoint Verification

```bash
cat .ccskill-gmail/endpoint
# If a URL is displayed, the endpoint file is correctly configured
```

### Response Inspection

```bash
# Pretty-print the response
.ccskill-gmail/api get action=list_labels | jq .
```
