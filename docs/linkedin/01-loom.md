# Post 1: Loom walkthrough

**Publish:** Thursday, October 1, 2026, 8:00 AM Eastern  
**Type:** native LinkedIn video (download from Loom; do not paste the Loom URL as the post itself)  
**Visual:** Canva 1920×1080 PNG thumbnail. Overlay: "Azure Website, Zero Passwords"

Before you upload: confirm the video says your name and the topic in the first 15–30 seconds. After it publishes, search `#Azure`, interact with three recent posts, and leave a useful comment on two.

## Post

```text
I built a website that runs straight from Azure Storage, with no server to rent or patch, and it redeploys itself every time I push to GitHub.

The part I'm proudest of: GitHub signs in to Azure without any stored password or key. Each deploy gets a short-lived OpenID Connect token, and the deploy identity can only upload files to one storage account.

In the video I:
• Build the whole thing with scripts: create, connect, and tear down
• Push a change and watch GitHub Actions deploy it in about 15 seconds
• Delete everything with one command

Two things I learned the hard way:
1. GitHub changed its token format for new repositories, and most tutorials still show the old one. My first deploy failed with AADSTS700213 (a token-mismatch error) until I matched the new format.
2. New Azure role assignments aren't instant. My scripts wait for them instead of falling back to storage account keys.

Code, step-by-step guide, and screenshots:
https://github.com/zsociety47/azure-static-website-poc

#Azure #GitHubActions #CICD #CloudComputing #DevOps
```

## Notes

- Upload the video file from a computer. After processing, set **Video thumbnail** to the Canva PNG.
- Hashtags: 3 specific (`#Azure` `#GitHubActions` `#CICD`), 2 broad (`#CloudComputing` `#DevOps`).
