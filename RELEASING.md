# Releasing

This document describes how to cut a new release of Kiro Kantoku.

## Prerequisites

### One-time setup (Apple Developer)

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)
2. Create a "Developer ID Application" certificate in the Apple Developer portal
3. Download and install the certificate in Keychain Access
4. Export the certificate as a .p12 file:
   - Open Keychain Access
   - Find "Developer ID Application: Your Name"
   - Right-click → Export
   - Save as .p12 with a strong password

### One-time setup (GitHub Secrets)

Add these secrets to the kiro-kantoku repository (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate (`base64 -i certificate.p12`) |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the .p12 |
| `APPLE_DEVELOPER_NAME` | Your name as it appears on the certificate (e.g., "Ryan Cormack") |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_TEAM_ID` | Your 10-character Team ID (find in Apple Developer portal) |
| `APPLE_APP_PASSWORD` | App-specific password from [appleid.apple.com](https://appleid.apple.com) |
| `HOMEBREW_TAP_TOKEN` | GitHub PAT with `repo` scope for the tap repository |

If you already have these configured for kiro-mcp-manager, you can reuse the same values.

To create an app-specific password:
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in → Security → App-Specific Passwords
3. Generate a new password for "GitHub Actions"

### One-time setup (Homebrew Tap)

1. Create a public GitHub repository named `ryancormack/homebrew-kiro-kantoku`
2. The release workflow will push the `Casks/` directory automatically

## Cutting a Release

1. Commit any final changes:
   ```bash
   git add .
   git commit -m "Prepare release v1.0.0"
   ```

2. Create and push a version tag:
   ```bash
   git tag v1.0.0
   git push origin main --tags
   ```

3. The GitHub Actions workflow will automatically:
   - Run tests
   - Build the app with `swift build -c release`
   - Assemble the `.app` bundle
   - Sign it with your Developer ID certificate
   - Submit for Apple notarization
   - Create a DMG and upload it to a GitHub Release
   - Update the Homebrew Cask formula in the tap repository

## Installing via Homebrew

Once released, users can install with:

```bash
brew tap ryancormack/kiro-kantoku
brew install --cask kiro-kantoku
```

## Troubleshooting

### Notarization fails
- Check that your Apple Developer account is in good standing
- Verify the app-specific password is correct
- Check the notarization log: `xcrun notarytool log <submission-id> --apple-id ... --team-id ...`

### Signing fails
- Verify the certificate hasn't expired
- Check that `APPLE_DEVELOPER_NAME` matches exactly what's on the certificate
- Re-export the certificate and update the GitHub secret

### Build fails
- Check the Xcode version in the workflow matches what's available on the runner
- Verify the project builds locally with `swift build -c release`

### Signing secrets not configured
- If the `APPLE_CERTIFICATE_BASE64` secret is empty, the workflow skips signing and notarization
- The DMG will still be created and uploaded, but users will see Gatekeeper warnings
