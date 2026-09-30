# Post 3: Architecture diagram

**Publish:** Monday, October 5, 2026, 8:00 AM Eastern  
**Visual:** export of the README architecture diagram. Highlight the dashed "OpenID Connect token" arrow.

## Post

```text
Solid line: how visitors reach the site.
Dashed lines: how code gets there.
Green: identity. That's the part that replaces passwords.

GitHub sends a short-lived OpenID Connect token. Azure accepts it only from this repo, to this one storage account.

Which arrow would you tighten first?

https://github.com/zsociety47/azure-static-website-poc

#Azure #GitHubActions #OIDC #CloudComputing #DevOps
```
