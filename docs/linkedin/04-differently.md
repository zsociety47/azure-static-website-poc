# Post 4: What I'd do differently

**Publish:** Tuesday, October 6, 2026, 8:00 AM Eastern  
**Visual:** the failed GitHub Actions run (red) next to a passing one

## Post

```text
My deploy pipeline failed today, and it was my own fault.

I pushed a change about a minute after granting the deploy identity its storage role. Azure role assignments aren't instant, so the upload hit "You do not have the required permissions" even though everything was configured correctly.

My setup script already handles this: it retries every 15 seconds for up to 10 minutes. The pipeline didn't.

If I rebuilt this, I'd give the workflow the same patience: wrap the upload in a short retry so a fresh role assignment doesn't turn the build red.

One more change while I'm there: swap `az storage blob upload-batch` for `az storage blob sync --delete-destination true`, so files I remove from the repo also disappear from the live site.

Small gaps like this are why I build it, break it, and write down what happened.

https://github.com/zsociety47/azure-static-website-poc

#Azure #GitHubActions #AzureCLI #CloudComputing #DevOps
```

## Notes

- Left in the "I'd" wording on purpose. The pipeline still does not retry. If you add the retry before October 6, change "I'd" to "I did" and attach a before-and-after of the badge.
- "Today" will be stale by October 6. Before posting, change it to "this week" or name the day.
- For the visual: failed run is commit `54c45b2` ("Add Loom walkthrough video…"). Pair it with any green run after the role took effect.
