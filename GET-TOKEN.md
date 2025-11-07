# Quick Guide: Get GitHub Token

To create the release automatically, you need a GitHub Personal Access Token:

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: "UvcPaneler Release"
4. Expiration: Choose "90 days" or "No expiration"
5. Select scope: Check **`repo`** (Full control of private repositories)
6. Click "Generate token"
7. **Copy the token immediately** (you won't see it again!)

Then run:
```powershell
.\create-release.ps1 -GitHubToken "YOUR_TOKEN_HERE"
```

