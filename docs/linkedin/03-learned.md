# Post 3: One thing I learned

**Publish:** Monday, October 5, 2026, 8:00 AM Eastern  
**Visual:** the README architecture diagram, with the OpenID Connect token arrow between GitHub Actions and the app registration highlighted

## Post

```text
My first deploy failed with AADSTS700213 (a token-mismatch error), and every tutorial I followed was out of date.

The setup: GitHub Actions signs in to Azure with an OpenID Connect (OIDC) token, so there is no stored password or key. Azure only accepts the token if its "subject" matches what you registered.

The catch: GitHub changed the subject format for new repositories. It now includes the immutable repository ID, not just the repo name. Most guides, and the portal's own "GitHub Actions" scenario, still build the old format. The result is a token-mismatch error that tells you very little.

The fix: my setup script now reads the subject from GitHub itself instead of assuming the format.

What I took from it: when authentication fails, compare what the token actually says to what the other side expects. Don't copy the tutorial.

https://github.com/zsociety47/azure-static-website-poc

#Azure #GitHubActions #OIDC #CloudComputing #DevOps
```

## Notes

- `AADSTS700213` is spelled out in the first line as a token-mismatch error so readers outside Azure can follow.
- Export the Mermaid diagram from the README (GitHub's diagram renderer, or mermaid.live) and mark the dashed "OpenID Connect token" arrow.
