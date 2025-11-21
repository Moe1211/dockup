# GitHub App Setup Guide for DockUp

This guide will walk you through creating and configuring a GitHub App for DockUp. GitHub Apps provide a more secure and scalable way to authenticate with GitHub repositories compared to SSH deploy keys.

## Why GitHub Apps?

- **No per-repository setup**: Install once on an organization or account, works for all repos
- **Better permissions**: Fine-grained control over what the app can access
- **More secure**: Tokens are short-lived and automatically rotated
- **Recommended by GitHub**: The modern way to integrate with GitHub

## Prerequisites

- A GitHub account
- Admin access to the repositories you want to deploy
- DockUp installed on your VPS

## Step 1: Register a GitHub App

1. Go to your GitHub account settings:
   - Click your profile picture → **Settings**
   - Or go directly to: https://github.com/settings/apps

2. Click **Developer settings** (left sidebar)

3. Click **GitHub Apps** (under Developer settings)

4. Click **New GitHub App** button

5. Fill in the app details:

   **Basic Information:**
   - **GitHub App name**: `DockUp` (or any name you prefer)
   - **Homepage URL**: `https://github.com/Moe1211/dockup` (or your DockUp repo)
   - **User authorization callback URL**: Leave empty (not needed for server-to-server)
   - **Setup URL**: Leave empty (not needed)
   - **Webhook URL**: Leave empty (DockUp handles webhooks separately)
   - **Webhook secret**: Leave empty (DockUp uses its own webhook secrets)

   **Permissions:**
   - **Repository permissions:**
     - **Contents**: `Read-only` (required for cloning repositories)
     - **Metadata**: `Read-only` (required, automatically granted)
   
   **Where can this GitHub App be installed?**
   - Select **Only on this account** (for personal repos) or **Any account** (if you want to share it)

6. Click **Create GitHub App**

## Step 2: Generate a Private Key

1. After creating the app, you'll be on the app's settings page

2. Scroll down to **Private keys** section

3. Click **Generate a private key**

4. **IMPORTANT**: GitHub will download a `.pem` file. Save this file securely - you won't be able to download it again!

5. The file will be named something like `dockup.2024-01-01.private-key.pem`

6. **Note your App ID**: You'll see it at the top of the page (e.g., "App ID: 123456")

## Step 3: Install the GitHub App

You need to install the app on the repositories or organization where you want to use DockUp.

### Option A: Install on Specific Repositories

1. On your GitHub App settings page, click **Install App** (left sidebar)

2. Click **Install** next to your account or organization

3. Choose **Only select repositories**

4. Select the repositories you want to deploy with DockUp

5. Click **Install**

6. **Note your Installation ID**: After installation, look at the URL. It will be something like:
   ```
   https://github.com/settings/installations/78901234
   ```
   The number at the end (78901234) is your Installation ID.

### Option B: Install on All Repositories

1. Follow steps 1-2 above

2. Choose **All repositories**

3. Click **Install**

4. Note your Installation ID from the URL

## Step 4: Configure DockUp on Your VPS

Now you need to provide DockUp with your GitHub App credentials.

### Get Your Credentials

You need three pieces of information:

1. **App ID**: Found on your GitHub App settings page (top of the page)
2. **Installation ID**: Found in the installation URL after installing the app
3. **Private Key**: The `.pem` file you downloaded

### Configure DockUp

Run the configure command from your local machine:

```bash
dockup configure-github-app user@vps-ip
```

You'll be prompted to enter:
- App ID
- Installation ID  
- Private key (paste the entire contents of the .pem file)

Alternatively, you can provide the values directly:

```bash
dockup configure-github-app user@vps-ip \
  --app-id 123456 \
  --installation-id 78901234 \
  --private-key "$(cat path/to/your-private-key.pem)"
```

The credentials will be securely stored on your VPS at `/etc/dockup/github-app.json`.

## Step 5: Test the Setup

### Test 1: Verify Configuration

Check that credentials are stored correctly:

```bash
ssh user@vps-ip "cat /etc/dockup/github-app.json | jq '.app_id, .installation_id'"
```

You should see your App ID and Installation ID.

### Test 2: Deploy a Repository

1. Navigate to a repository you want to deploy:

```bash
cd my-project
```

2. Run the deploy command:

```bash
dockup deploy user@vps-ip
```

3. Watch for any errors. If you see authentication errors, check:
   - App ID is correct
   - Installation ID is correct
   - Private key was pasted completely (including BEGIN/END lines)
   - The app is installed on the repository you're trying to deploy

### Test 3: Verify Cloning Works

SSH into your VPS and manually test cloning:

```bash
ssh user@vps-ip
```

The agent should automatically use the GitHub App token for git operations. Check the logs:

```bash
journalctl -u dockup -f
```

Then trigger a deployment and watch for any authentication errors.

## Troubleshooting

### Error: "Failed to generate installation token"

**Possible causes:**
- App ID is incorrect
- Private key is malformed (check it includes BEGIN/END lines)
- Private key doesn't match the App ID

**Solution:**
- Re-run `dockup configure-github-app` with correct values
- Make sure you copied the entire private key including headers

### Error: "Installation not found"

**Possible causes:**
- Installation ID is incorrect
- App is not installed on the repository you're trying to access

**Solution:**
- Verify the Installation ID in the GitHub App installation URL
- Make sure the app is installed on the repository/organization

### Error: "Repository access denied"

**Possible causes:**
- App is not installed on the repository
- App doesn't have access to the repository (if installed on "selected repositories")

**Solution:**
- Go to GitHub App → Install App → Select the repository
- Or install the app on "All repositories"

### Error: "Token expired"

**Possible causes:**
- Installation tokens expire after 1 hour
- This is normal - DockUp should automatically regenerate tokens

**Solution:**
- This should be handled automatically by DockUp
- If you see this error repeatedly, check the agent logs

## Security Best Practices

1. **Protect your private key**: 
   - Never commit the `.pem` file to git
   - Store it securely (password manager, encrypted storage)
   - The key is stored on your VPS at `/etc/dockup/github-app.json` with restricted permissions

2. **Minimal permissions**:
   - Only grant "Read-only" access to Contents
   - Don't grant write access unless you need it

3. **Repository access**:
   - Install only on repositories that need deployment
   - Use "Only select repositories" when possible

4. **Regular rotation**:
   - Consider regenerating the private key periodically
   - Update DockUp configuration when you rotate keys

## Next Steps

Once your GitHub App is configured:

1. ✅ Your VPS can clone any repository where the app is installed
2. ✅ No need to add deploy keys to individual repositories
3. ✅ Deploy with: `dockup deploy user@vps-ip`

## Example: Complete Setup Flow

```bash
# 1. Create GitHub App (via GitHub web interface)
#    - App ID: 123456
#    - Installation ID: 78901234
#    - Private key: saved to ~/dockup-key.pem

# 2. Configure DockUp
dockup configure-github-app root@95.217.208.54 \
  --app-id 123456 \
  --installation-id 78901234 \
  --private-key "$(cat ~/dockup-key.pem)"

# 3. Deploy your first repository
cd my-project
dockup deploy root@95.217.208.54

# 4. Verify it works
ssh root@95.217.208.54 "journalctl -u dockup -n 50"
```

## Need Help?

- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Review GitHub App documentation: https://docs.github.com/en/apps/creating-github-apps
- Open an issue on the DockUp repository

