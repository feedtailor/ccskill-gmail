# Troubleshooting

[← Back to README](../README.md) ・ [日本語版](troubleshooting.ja.md)

## Account registration fails midway

Re-run `ccskill-gmail account add`. A failed registration can leave a stranded GAS project on Google's side; remove it manually from [script.google.com](https://script.google.com) before retrying.

## Redirect loop or "Unable to open file" when the browser opens

This happens when you're already signed in to multiple Google accounts in the browser, or a session from a different account is still cached. Try the following:

1. Copy the **Authorization URL** shown in your terminal (starts with `https://script.google.com/macros/s/...`)
2. Open a **new private/incognito window** (close any existing private windows first)
3. Go to [accounts.google.com](https://accounts.google.com) and sign in with the Google account you want to bind
4. In the same window, paste the Authorization URL from step 1 into the address bar
5. Click "Allow"

**Important:**
- Do **not** copy the URL from the browser's error page — always use the URL **shown in your terminal**
- Sign in at accounts.google.com **before** opening the Authorization URL. Opening the URL first will trigger the same redirect loop

## "This app isn't verified" warning (personal Google accounts)

With a personal Google account (`@gmail.com`, etc.), authorization shows a "This app isn't verified" warning. ccskill-gmail deploys a personal Apps Script in your own account that uses sensitive Gmail scopes, and it hasn't gone through Google's public verification. It's a script you built and authorize yourself, so it's safe to proceed.

1. Click "Advanced"
2. Click "Go to <project> (unsafe)"
3. Click "Allow" on the permission list

Google Workspace accounts treated as internal apps may not see this warning.

## Multi-account OAuth errors

If you encounter authentication errors with multiple accounts, run `ccskill-gmail doctor`. The doctor command checks the full chain — clasp login, OAuth tokens, the account registry, endpoint connectivity — and tells you exactly what's broken with fix suggestions.

## Something doesn't work after update

Run `ccskill-gmail doctor` to diagnose. If the issue persists, try `ccskill-gmail update --force` to redeploy the GAS project from scratch.

## A change or operation doesn't take effect

You may be talking to a different deployment than you expect — the same account can have both an old per-project deployment and the shared one. Run `ccskill-gmail api whoami` and check `endpoint`. If it points at the shared deployment, push code changes with `ccskill-gmail account update` (the project's `update --force` only updates the old per-project deployment, so your change won't show up).
