# Post 1: Video

**Publish:** Thursday, October 1, 2026, 8:00 AM Eastern  
**Type:** native LinkedIn video (download the file from Loom; never paste a Loom URL)  
**Visual:** still frame of your face from the intro, Canva 1920×1080 PNG. Overlay: "Azure Website, Zero Passwords"

## Check this recording first (Flow A, ~11 minutes)

I checked the recording script and the stills from Loom, not a frame-by-frame watch. Confirm these on the file before you upload.

| Guide | This recording | What to do |
|---|---|---|
| Face on camera in intro, build, and outro | Stills show the camera bubble. Confirm it stays on the whole time. | If you turned the camera off during the terminal work, keep a face-on intro and outro at minimum. |
| First 30 seconds: name, who you are, what you're building, the business problem and why it matters | The script opens with what you built and the security angle. It does not say your name, who you are, or the business problem. | Record a 20–30 second intro clip and put it at the start. |
| Outro: business use case, plus what you'd change | The script ends on success criteria and "thanks for watching." It does not cover what you'd change. | Record a 20–30 second outro clip and put it at the end. |

### Intro clip (say this)

"Hi, I'm Zeon Stewart, a cloud engineer. I'm building a static website on Azure Blob Storage so a team can publish a public site without renting a server or storing deploy passwords. That matters because keys sitting in GitHub are how brochure sites get compromised."

### Outro clip (say this)

"The business use case is a public site that updates itself on every push, with an identity that can only write to one storage account. If I did this again, I'd make the GitHub Actions upload wait for Azure role assignments the same way the setup script already does, so a fresh identity doesn't turn the pipeline red. Thanks for watching."

Stitch the two clips onto the existing video in Loom or iMovie. You do not need to re-record the middle.

After it publishes: search `#Azure`, interact with three recent posts, and leave a useful comment on two.

## Post

```text
A public website with no server to patch. And no password stored to deploy it.

I recorded the full build on Azure Storage and GitHub Actions.

Teams still babysit VMs and leak keys for brochure sites. This shows you don't have to.

Would you trust a deploy identity that can only write to one storage account?

https://github.com/zsociety47/azure-static-website-poc

#Azure #GitHubActions #CICD #CloudComputing #DevOps
```
