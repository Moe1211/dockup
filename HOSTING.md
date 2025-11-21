# Hosting DockUp Installer

This guide explains how to host the DockUp installer and HTML page so developers can use the one-line command.

## Files to Host

You need to host these files publicly:

1. **`install.sh`** - The bootstrap installer script
2. **`dockup`** - The main CLI script
3. **`main.go`** - The Go agent source code
4. **`index.html`** - The documentation page

## Option 1: GitHub (Recommended)

### Setup

1. Push your DockUp repository to GitHub
2. Update the URLs in `install.sh` to point to your repository:

```bash
# In install.sh, update these lines:
DOCKUP_REPO_URL="https://raw.githubusercontent.com/YOUR_USERNAME/dockup/main"
```

3. Host the HTML page using GitHub Pages:
   - Go to your repository Settings → Pages
   - Select the branch and folder (or use a custom domain)
   - The `index.html` will be served automatically

### URLs

- Installer: `https://raw.githubusercontent.com/YOUR_USERNAME/dockup/main/install.sh`
- HTML Page: `https://YOUR_USERNAME.github.io/dockup/` (if using GitHub Pages)

## Option 2: Your Own Server

### Using Nginx

1. Create a directory for static files:
```bash
mkdir -p /var/www/dockup
```

2. Copy files:
```bash
cp install.sh dockup main.go index.html /var/www/dockup/
```

3. Configure Nginx:
```nginx
server {
    listen 80;
    server_name dockup.yourdomain.com;

    root /var/www/dockup;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Serve install.sh with proper headers
    location /install.sh {
        add_header Content-Type text/plain;
    }

    # Serve dockup script
    location /dockup {
        add_header Content-Type text/plain;
    }

    # Serve main.go
    location /main.go {
        add_header Content-Type text/plain;
    }
}
```

### Using Caddy

Create a `Caddyfile`:
```
dockup.yourdomain.com {
    root * /var/www/dockup
    file_server
}
```

## Option 3: CDN (Cloudflare Pages, Netlify, Vercel)

1. Upload your files to the CDN
2. Update URLs in `install.sh` to match your CDN URLs
3. The HTML page will be served automatically

## Updating install.sh URLs

After hosting, update the default URLs in `install.sh`:

```bash
# Replace these lines in install.sh:
DOCKUP_REPO_URL="${DOCKUP_REPO_URL:-https://your-actual-domain.com}"
DOCKUP_SCRIPT_URL="${DOCKUP_SCRIPT_URL:-$DOCKUP_REPO_URL/dockup}"
MAIN_GO_URL="${MAIN_GO_URL:-$DOCKUP_REPO_URL/main.go}"
```

Or set environment variables when calling:
```bash
DOCKUP_REPO_URL=https://your-domain.com curl -fsSL https://your-domain.com/install.sh | bash -s -- user@vps-ip setup
```

## Testing

Test the installer locally:
```bash
# Test setup command
curl -fsSL http://localhost:8000/install.sh | bash -s -- user@vps-ip setup

# Test init command
cd /path/to/your/repo
curl -fsSL http://localhost:8000/install.sh | bash -s -- user@vps-ip init
```

## Security Considerations

1. **HTTPS**: Always use HTTPS in production
2. **Content Verification**: Consider adding checksums for downloaded files
3. **Rate Limiting**: Implement rate limiting on your server to prevent abuse

## Example: Complete Setup with GitHub

1. Push to GitHub:
```bash
git remote add origin https://github.com/YOUR_USERNAME/dockup.git
git push -u origin main
```

2. Update `install.sh`:
```bash
sed -i 's|yourusername|YOUR_USERNAME|g' install.sh
```

3. Enable GitHub Pages:
   - Settings → Pages → Source: `main` branch → `/ (root)`

4. Share the one-liner:
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/dockup/main/install.sh | bash -s -- user@vps-ip init
```

## Custom Domain

If you have a custom domain:

1. Update `install.sh` URLs to use your domain
2. Update `index.html` to reference your domain in examples
3. Configure DNS to point to your hosting provider

Example:
```bash
# In install.sh
DOCKUP_REPO_URL="https://dockup.yourdomain.com"
```

Then the one-liner becomes:
```bash
curl -fsSL https://dockup.yourdomain.com/install.sh | bash -s -- user@vps-ip init
```

