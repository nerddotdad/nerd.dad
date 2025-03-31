---
comments: true
date:
  created: 2025-03-31
draft: false
categories:
  - Nerd Dad Site
---
# CI/CD for this site

This has been quite a day. Along with working on-call I decided I would take on the CI/CD pipeline for automatic site builds.

It's using github actions and while I'm still new to a lot of this I know enough to be dangerous.

It's almost 1am so I'll make this brief. I wanted to use github actions to determine if my commit message started with buid. If it did then it would build the env and run the mike commands to deploy my site! Pretty cool! you'll be able to see previous versions of my site from a dropdown in the header. I may in the future tie these versions to something important but for now it's just a way for me to do a bit of archiving.